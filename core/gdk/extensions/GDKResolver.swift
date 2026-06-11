import Foundation
import UIKit
import greenaddress
import hw

public protocol PopupResolverDelegate: AnyObject {
    func code(_ method: String, attemptsRemaining: Int?, enable2faCallMethod: Bool, network: NetworkSecurityCase, failure: Bool) async throws -> String
    func method(_ methods: [String]) async throws -> String
}

public protocol BcurResolver {
    func requestData(_ :ResolveCodeAuthData) async throws -> String
}

public enum ResolverError: Error {
    case failure(localizedDescription: String)
    case cancel(localizedDescription: String)
}

public enum TwoFactorCallError: Error {
    case failure(localizedDescription: String)
    case cancel(localizedDescription: String)
}

public protocol ProgressDelegate: AnyObject {
    func start()
    func stop()
}

public class GDKResolver {

    let network: NetworkSecurityCase
    let connected: () -> Bool
    let twoFactorCall: TwoFactorCall?
    let popupDelegate: PopupResolverDelegate?
    let progressDelegate: ProgressDelegate?
    let bcurDelegate: BcurResolver?
    let hwDelegate: HwResolverDelegate?
    let hwDevice: HWProtocol?
    let gdkSession: GDKSession?
    var prevResolveCode: [String: Any]? = nil

    public init(_ twoFactorCall: TwoFactorCall?,
                gdkSession: GDKSession?,
                popupDelegate: PopupResolverDelegate? = nil,
                progressDelegate: ProgressDelegate? = nil,
                hwDelegate: HwResolverDelegate? = nil,
                hwInterfaceDelegate: HwInterfaceResolver? = nil,
                bcurDelegate: BcurResolver? = nil,
                hwDevice: HWProtocol? = nil,
                network: NetworkSecurityCase,
                connected: @escaping () -> Bool = { true }) {
        self.twoFactorCall = twoFactorCall
        self.gdkSession = gdkSession
        self.popupDelegate = popupDelegate
        self.bcurDelegate = bcurDelegate
        self.hwDelegate = hwDelegate
        self.hwDelegate?.setInterfaceDelegate(hwInterfaceDelegate)
        self.network = network
        self.connected = connected
        self.hwDevice = hwDevice
        self.progressDelegate = progressDelegate
    }

    public func resolve() async throws -> [String: Any]? {
        let res = try self.twoFactorCall?.getStatus()
        let status = res?["status"] as? String
        if status == "done" {
            return res
        } else {
            try await resolving(res ?? [:])
            return try await resolve()
        }
    }

    private func resolving(_ res: [String: Any]) async throws {
        let status = res["status"] as? String
        let name = res["name"] as? String
        print("GDKResolver \(network.rawValue) \(res)")
        switch status {
        case "done":
            break
        case "error":
            let error = res["error"] as? String ?? ""
            throw TwoFactorCallError.failure(localizedDescription: error)
        case "call":
            try await self.waitConnection()
            try self.twoFactorCall?.call()
        case "request_code":
            let methods = res["methods"] as? [String] ?? []
            if methods.count > 1 {
                let method = try await self.popupDelegate?.method(methods)
                try await self.waitConnection()
                try self.twoFactorCall?.requestCode(method: method)
            } else {
                try self.twoFactorCall?.requestCode(method: methods[0])
            }
        case "resolve_code":
            // Hardware wallet interface resolver
            if let requiredData = res["required_data"] as? [String: Any],
                let action = requiredData["action"] as? String,
                let device = requiredData["device"] as? [String: Any],
                let hwdevice = HWDevice.from(device) as? HWDevice {
                let res = try await hwDelegate?.resolveCode(action: action, device: hwdevice, requiredData: requiredData, chain: network.chain, hwDevice: hwDevice)
                try self.twoFactorCall?.resolveCode(code: res.stringify())
            } else if name == "bcur_decode", let bcurDelegate = bcurDelegate {
                let authData = res["auth_data"] as? [String: Any]
                let info = ResolveCodeAuthData.from(authData ?? [:]) as? ResolveCodeAuthData
                let code = try await bcurDelegate.requestData(info ?? ResolveCodeAuthData())
                try self.twoFactorCall?.resolveCode(code: code)
            } else {
                // Software wallet interface resolver
                let resolveCode = ResolveCodeData.from(res) as? ResolveCodeData
                let res = try? self.gdkSession?.getTwoFactorConfig()
                var enable2faCallMethod = false
                if let config = TwoFactorConfig.from(res ?? [:]) as? TwoFactorConfig {
                    enable2faCallMethod = config.enableMethods.count == 1 && config.enableMethods.contains("sms")
                }
                let code = try await self.popupDelegate?.code(
                    resolveCode?.method ?? "",
                    attemptsRemaining: resolveCode?.attemptsRemaining,
                    enable2faCallMethod: enable2faCallMethod,
                    network: network,
                    failure: prevResolveCodeMethod() == "gauth"
                )

                try await self.waitConnection()
                try self.twoFactorCall?.resolveCode(code: code)
            }
            prevResolveCode = res
        default:
            break
        }
    }

    func prevResolveCodeMethod() -> String? {
        if let prevResolveCode = prevResolveCode, let prevResolveCode = ResolveCodeData.from(prevResolveCode) as? ResolveCodeData {
            return prevResolveCode.method
        }
        return nil
    }

    func waitConnection() async throws {
        var attempts = 0
        func attempt() async throws {
            if attempts == 5 {
                throw GaError.TimeoutError()
            }
            attempts += 1
            let status = self.connected()
            if !status {
                try await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                try await attempt()
            }
        }
        return try await attempt()
    }
}
