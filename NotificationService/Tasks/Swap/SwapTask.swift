import Foundation
import UserNotifications
import os.log
import core
import LiquidWalletKit

import CoreData

public class SwapTask {
    private let lwkBoltzBackend: LwkBoltzBackend
    private let startTime: Date
    // Timeout for notifications
    // ~30s = standard timeout
    // ~25s = cleanup zone
    private let maxDuration: TimeInterval = 30.0
    
    init(lwkBoltzBackend: LwkBoltzBackend) {
        self.startTime = Date()
        self.lwkBoltzBackend = lwkBoltzBackend
    }

    public func start(xpubHashId: String, secret: String, swapId: String) async throws -> BoltzSwap {
        return try await withTaskCancellationHandler {
            try await performSwap(xpubHashId: xpubHashId, secret: secret, swapId: swapId)
        } onCancel: {
            logger.info("LwkSwapTask: OS Timeout triggered. Cleaning up.")
            // This is triggered INSTANTLY when task.cancel() is called.
            // It does NOT wait for the block above to finish.
            Task {
                await lwkBoltzBackend.disconnect()
            }
        }
    }
    
    private func performSwap(xpubHashId: String, secret: String, swapId: String) async throws -> BoltzSwap {
        guard let persistentId = try await BoltzController.shared.fetchID(byId: swapId),
              let swap = try await BoltzController.shared.get(with: persistentId),
              let swapData = swap.data else {
            logger.error("LwkSwapTask: Swap \(swapId, privacy: .public) not present")
            throw NotificationError.InvalidSwap
        }
        logger.info("LwkSwapTask: Swap \(swapId, privacy: .public) \(swap.isPending ? "pending" : "completed")")
        GdkInit.defaults().run()
        _ = try await lwkBoltzBackend
            .loginUser(Credentials(mnemonic: secret), xpubHashId: xpubHashId)
        logger.info("LwkSwapTask: connected")
        switch swap.type {
        case .Submarine:
            if let pay = try await lwkBoltzBackend.restorePreparePay(data: swapData) {
                _ = try await loopSwap(
                    xpubHashId: xpubHashId,
                    lwkBoltzBackend: lwkBoltzBackend,
                    persistentId: persistentId,
                    swap: SwapResponse.submarine(pay))
            }
        case .ReverseSubmarine:
            if let invoice = try await lwkBoltzBackend.restoreInvoice(data: swapData) {
                _ = try await loopSwap(
                    xpubHashId: xpubHashId,
                    lwkBoltzBackend: lwkBoltzBackend,
                    persistentId: persistentId,
                    swap: SwapResponse.reverseSubmarine(invoice))
            }
        case .Chain:
            if let lockup = try await lwkBoltzBackend.restoreLockup(data: swapData) {
                _ = try await loopSwap(
                    xpubHashId: xpubHashId,
                    lwkBoltzBackend: lwkBoltzBackend,
                    persistentId: persistentId,
                    swap: SwapResponse.chain(lockup))
            }
        case nil:
            throw NotificationError.InvalidNotification
        }
        guard let swap = try await BoltzController.shared.get(with: persistentId) else {
            throw NotificationError.Failed
        }
        return swap
    }

    nonisolated public func loopSwap(xpubHashId: String, lwkBoltzBackend: LwkBoltzBackend, persistentId: NSManagedObjectID, swap: SwapResponse) async throws -> PaymentState {
        let monitor = SwapMonitor(xpubHashId: xpubHashId, lwkBoltzBackend: lwkBoltzBackend)
        var state = PaymentState.continue
        var swap = swap
        repeat {
            try Task.checkCancellation()
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > (maxDuration - 5.0) {
                logger.info("LwkSwapTask: Approaching execution limit (\(elapsed)s). Cleaning up.")
                await lwkBoltzBackend.disconnect()
                throw NotificationError.Timeout
            }
            state = try await monitor.handleSingleSwap(persistentId: persistentId, swap: &swap)
        } while state == PaymentState.continue && !Task.isCancelled
        await lwkBoltzBackend.disconnect()
        return state
    }
}
