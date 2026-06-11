import Foundation
import os.log
import core
import gdk

public class LightningTask: NewNotificationDelegate {
    private let maxDuration: TimeInterval = 20.0
    private var isPaymentFinished: Bool = false
    private var lightningSession: LightningSessionManager?
    
    public init() {}
    
    public func start(xpubHashId: String, secret: String) async throws {
        lightningSession = LightningSessionManager(newNotificationDelegate: self)
        
        try await withTaskCancellationHandler {
            try await performLightningTask(secret: secret)
        } onCancel: {
            logger.info("LightningTask: OS Timeout triggered. Cleaning up.")
            Task { [weak self] in
                await self?.lightningSession?.disconnect()
            }
        }
    }
    
    private func performLightningTask(secret: String) async throws {
        guard let lightningSession = lightningSession else { return }
        logger.info("LightningTask: Connecting to node")
        
        GdkInit.defaults().run()
        _ = try await lightningSession.loginUser(Credentials(mnemonic: secret))
        logger.info("LightningTask: Connected")
        
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < maxDuration {
            try Task.checkCancellation()
            
            if isPaymentFinished {
                logger.info("LightningTask: Payment finished. Exiting early.")
                break
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        await lightningSession.disconnect()
    }
}

extension LightningTask {
    public func didReceive(event: EventNotificationTypes, networkType: NetworkSecurityCase) {
        if case .invoicePaid = event {
            logger.info("LightningTask: Received invoicePaid event")
            isPaymentFinished = true
        }
    }
}
