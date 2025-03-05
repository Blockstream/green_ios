import Foundation
import BreezSDK
import os.log
import core
import gdk

class BreezSDKConnector: EventListener {

    private static var lightningSession: LightningSessionManager? = nil
    private var sdkListener: EventListener? = nil

    func register(credentials: Credentials, listener: EventListener) async throws -> BlockingBreezServices? {
        sdkListener = listener
        if BreezSDKConnector.lightningSession == nil {
            return try await connectSDK(credentials: credentials)
        }
        return BreezSDKConnector.lightningSession?.lightBridge?.breezSdk
    }

    func unregister() async {
        try? await disconnect()
    }

    func disconnect() async throws {
        try await BreezSDKConnector.lightningSession?.disconnect()
        sdkListener = nil
        BreezSDKConnector.lightningSession = nil
    }

    func connectSDK(credentials: Credentials) async throws -> BlockingBreezServices? {
        // Connect to the Breez SDK make it ready for use
        GdkInit.defaults().run()
        BreezSDKConnector.lightningSession = LightningSessionManager(NetworkSecurityCase.bitcoinSS.gdkNetwork)
        try await BreezSDKConnector.lightningSession?.smartLogin(credentials: credentials, listener: self)
        return BreezSDKConnector.lightningSession?.lightBridge?.breezSdk
    }

    func onEvent(e: BreezSDK.BreezEvent) {
        sdkListener?.onEvent(e: e)
    }
}

class SDKLogListener: LogStream {
    private var logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func log(l: LogEntry) {
        if l.level != "TRACE" {
            logger.info("greenlight: [\(l.level)] \(l.line)")
        }
    }
}
