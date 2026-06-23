import Foundation
import os.log
import core

public class LightningTask: NewNotificationDelegate {
    private let maxDuration: TimeInterval = 20.0
    private var isPaymentFinished: Bool = false
    private(set) var glNetworkBackend: GlNetworkBackend!

    public init() {
        glNetworkBackend = GlNetworkBackend(
            network: NetworkId.lightningMainnet.gdkNetwork,
            newNotificationDelegate: self
        )
    }
    
    public func start(xpubHashId: String, secret: String) async throws {
        try await withTaskCancellationHandler {
            try await performLightningTask(xpubHashId: xpubHashId, secret: secret)
        } onCancel: {
            logger.info("LightningTask: OS Timeout triggered. Cleaning up.")
            Task { [weak self] in
                try await self?.glNetworkBackend.disconnect()
            }
        }
    }
    
    private func performLightningTask(xpubHashId: String, secret: String) async throws {
        logger.info("LightningTask: Connecting to node")
        try await glNetworkBackend.login(
            credentials: Credentials(mnemonic: secret),
            restore: false,
            parentXpub: xpubHashId)
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
        
        try? await glNetworkBackend.disconnect()
    }
}

extension LightningTask {
    public func didReceive(event: EventNotificationTypes, networkId: NetworkId) {
        if case .invoicePaid = event {
            logger.info("LightningTask: Received invoicePaid event")
            isPaymentFinished = true
        }
    }
}
