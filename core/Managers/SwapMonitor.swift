import Foundation
import CoreData
import LiquidWalletKit

public actor SwapMonitor {

    private let xpubHashId: String
    private let lwkSession: LwkSessionManager
    private var activeTasks: [NSManagedObjectID: Task<Void, Never>] = [:]

    public init(xpubHashId: String, lwkSession: LwkSessionManager) {
        self.xpubHashId = xpubHashId
        self.lwkSession = lwkSession
    }

    deinit {
        activeTasks.removeAll()
    }

    /// Called on wallet login to resume pending work
    public func start() async throws {
        try await BoltzController.shared.dump(xpubHashId: xpubHashId)
        let pendingIDs = try await getPendingSwaps()
        for swapId in pendingIDs {
            await monitorSwap(id: swapId)
        }
    }

    /// Called on restore wallet before wallet login to restore swaps, do before bootstrap()
    public func restoreSwaps(bitcoinAddress: String, liquidAddress: String) async throws {
        try await lwkSession.restoreSwaps(
            bitcoinAddress: bitcoinAddress,
            liquidAddress: liquidAddress,
            xpubHashId: xpubHashId)
    }

    public func monitorSwap(id: NSManagedObjectID) async {
        // Check if we are already monitoring this to avoid duplicates
        guard activeTasks[id] == nil else { return }
        // Create an isolated task for this specific transaction
        let task = Task {
            try? await handleSwap(id: id)
            // Cleanup: remove from dictionary once handleTransaction finishes
            await removeTask(for: id)
        }
        activeTasks[id] = task
    }

    private func removeTask(for id: NSManagedObjectID) {
        activeTasks.removeValue(forKey: id)
    }
    
    public func stop() async {
        for task in activeTasks {
            task.value.cancel()
        }
        // Give some time for tasks to cancel
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    private func getPendingSwaps() async throws -> [NSManagedObjectID] {
        try await BoltzController.shared.fetchPendingSwaps(xpubHashId: xpubHashId)
    }

    private func getPendingSwap(id: NSManagedObjectID) async throws -> BoltzSwap? {
        try await BoltzController.shared.get(with: id)
    }

    nonisolated private func handleSwap(id: NSManagedObjectID) async throws {
        let swap = try await getPendingSwap(id: id)
        guard let swap else { return }
        if swap.isPending == false { return }
        lwkLogger.info("\(swap.id ?? "", privacy: .public): \(swap.data?.prefix(128) ?? "")")
        switch swap.type {
        case .some(BoltzSwapTypes.Submarine):
            if let pay = try await lwkSession.restorePreparePay(data: swap.data ?? "") {
                lwkLogger.info("\(swap.id ?? "", privacy: .public) restored")
                let state = try await loopSwap(swap: SwapResponse.submarine(pay))
                lwkLogger.info("\(swap.id ?? "", privacy: .public) \(state.localized, privacy: .public)")
            }
        case .some(BoltzSwapTypes.ReverseSubmarine):
            if let invoice = try await lwkSession.restoreInvoice(data: swap.data ?? "") {
                lwkLogger.info("\(swap.id ?? "", privacy: .public) restored")
                let state = try await loopSwap(swap: SwapResponse.reverseSubmarine(invoice))
                lwkLogger.info("\(swap.id ?? "", privacy: .public) \(state.localized, privacy: .public)")
            }
        case .some(.Chain):
            if let lockup = try await lwkSession.restoreLockup(data: swap.data ?? "") {
                lwkLogger.info("\(swap.id ?? "", privacy: .public) restored")
                let state = try await loopSwap(swap: SwapResponse.chain(lockup))
                lwkLogger.info("\(swap.id ?? "", privacy: .public) \(state.localized, privacy: .public)")
            }
        case .none:
            lwkLogger.info("\(swap.id ?? "", privacy: .public) invalid")
        }
    }

    nonisolated public func handleSingleSwap(persistentId: NSManagedObjectID, swap: inout SwapResponse) async throws -> PaymentState {
        let swapId = try swap.swapId()
        do {
            let state = try swap.advance()
            switch state {
            case .continue:
                let data = try swap.serialize()
                lwkLogger.info("\(swapId, privacy: .public) updated with \(data.prefix(64), privacy: .public)")
                _ = try await BoltzController.shared.update(with: persistentId, newData: data, newIsPending: true)
                try await Task.sleep(nanoseconds: 100_000_000)
            case .success:
                lwkLogger.info("\(swapId, privacy: .public) completed successfully!")
                let newTxHash: String? = {
                    switch swap {
                    case .reverseSubmarine(let swap):
                        return try? swap.claimTxid()
                    case .submarine(let swap):
                        return try? swap.lockupTxid()
                    case .chain(let swap):
                        return try? swap.lockupTxid()
                    }
                }()
                _ = try await BoltzController.shared.update(with: persistentId, newIsPending: false, newTxHash: newTxHash)
            case .failed:
                lwkLogger.info("\(swapId, privacy: .public) failed!")
                _ = try await BoltzController.shared.update(with: persistentId, newIsPending: false)
            }
            return state
        } catch LwkError.NoBoltzUpdate {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            lwkLogger.info("\(swapId, privacy: .public) NoBoltzUpdate!")
            if let swap = try? await BoltzController.shared.get(with: persistentId) {
                return swap.isPending ? PaymentState.continue : PaymentState.success
            } else {
                return .failed
            }
        } catch LwkError.ObjectConsumed {
            lwkLogger.error("\(swapId, privacy: .public) object consumed")
            return .failed
        } catch {
            lwkLogger.error("\(swapId, privacy: .public) unrecoverable error: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    nonisolated public func loopSwap(swap: SwapResponse) async throws -> PaymentState {
        let swapId = try swap.swapId()
        lwkLogger.error("\(swapId, privacy: .public) loopSwap")
        let persistentId = try? await BoltzController.shared.fetchID(byId: swapId)
        guard let persistentId else {
            lwkLogger.error("\(swapId, privacy: .public) not found")
            throw LwkError.Generic(msg: "Swap not found")
        }
        var state = PaymentState.continue
        var swap = swap
        repeat {
            try Task.checkCancellation()
            state = try await self.handleSingleSwap(persistentId: persistentId, swap: &swap)
        } while state == PaymentState.continue && !Task.isCancelled
        return state
    }
}
