import Foundation
import AsyncBluetooth
import hw
import gdk
import UIKit
import core

class JadeManager {

    let jade: Jade
    var pinServerSession: SessionManager? = nil
    var warningPinShowed = false

    var customWhitelistUrls = [String]()
    var persistCustomWhitelistUrls: [String] {
        get { UserDefaults.standard.array(forKey: "whitelist_domains") as? [String] ?? [] }
        set { UserDefaults.standard.setValue(customWhitelistUrls, forKey: "whitelist_domains") }
    }

    init(connection: HWConnectionProtocol) {
        jade = Jade(connection: connection)
        jade.gdkRequestDelegate = self
    }

    func domain(from url: String) -> String? {
        let url = url.starts(with: "http://") || url.starts(with: "https://") ? url : "http://\(url)"
        let urlComponents = URLComponents(string: url)
        if let host = urlComponents?.host {
            if let port = urlComponents?.port {
                return "\(host):\(port)"
            }
            return host
        }
        return nil
    }

    public func disconnect() async throws {
        customWhitelistUrls = []
    }

    func connectPinServer(testnet: Bool) async throws {
        if pinServerSession == nil {
            let networkType: NetworkSecurityCase = testnet ? .testnetSS : .bitcoinSS
            pinServerSession = SessionManager(networkType)
        }
        try await pinServerSession?.connect()
    }
}

extension JadeManager: JadeGdkRequest {
    func bcurEncode(params: Any) async throws -> Any {
        guard let params = params as? BcurEncodeParams else {
            throw BLEManagerError.genericErr(txt: "Invalid bcur")
        }
        let res = try await pinServerSession?.bcurEncode(params: params)
        guard let res = res else {
            throw BLEManagerError.genericErr(txt: "Invalid bcur")
        }
        return res
    }

    @MainActor
    func showUrlValidationWarning(domains: [String], completion: @escaping (UIAlertOption) -> () = { _ in }) {
        if warningPinShowed {
            completion(.continue)
            return
        }
        DispatchQueue.main.async {
            let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "PinServerWarnViewController") as? PinServerWarnViewController {
                vc.onSupport = {
                    if let url = URL(string: ExternalUrls.pinServerSupport + Common.versionNumber) {
                        SafeNavigationManager.shared.navigate( url )
                    }
                    // navigating info center sends cancel event
                    completion(.cancel)
                }
                vc.onConnect = { [weak self] notAskAgain in
                    self?.warningPinShowed = true
                    self?.customWhitelistUrls += domains
                    if notAskAgain {
                        self?.persistCustomWhitelistUrls += self?.customWhitelistUrls ?? []
                    }
                    completion(.continue)
                }
                vc.onClose = {
                    completion(.cancel)
                }
                vc.domains = domains
                vc.modalPresentationStyle = .overFullScreen
                UIApplication.topViewController()?.present(vc, animated: false, completion: nil)
            }
        }
    }

    @MainActor
    func showTorWarning(domains: [String], completion: @escaping (UIAlertOption) -> () = { _ in }) {
        DispatchQueue.main.async {
            let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "EnableTorViewController") as? EnableTorViewController {
                vc.onConnect = { () in
                    completion(.continue)
                }
                vc.onClose = { () in
                    completion(.cancel)
                }
                vc.domains = domains
                vc.modalPresentationStyle = .overFullScreen
                UIApplication.topViewController()?.present(vc, animated: false, completion: nil)
            }
        }
    }

    @MainActor
    func showUrlValidationWarning(domains: [String]) async -> UIAlertOption {
        await withCheckedContinuation { continuation in
            showUrlValidationWarning(domains: domains) { result in
                continuation.resume(with: .success(result))
            }
        }
    }

    @MainActor
    func showTorWarning(domains: [String]) async -> UIAlertOption {
        await withCheckedContinuation { continuation in
            showTorWarning(domains: domains) { result in
                continuation.resume(with: .success(result))
            }
        }
    }

    func validateTor(urls: [String]) async -> Bool {
        if urls.allSatisfy({ $0.contains(".onion") || $0.isEmpty }) && AppSettings.shared.gdkSettings?.tor == false {
            switch await showTorWarning(domains: urls) {
            case .continue:
                if AppSettings.shared.gdkSettings?.tor == true {
                    try? await self.pinServerSession?.disconnect()
                    try? await self.pinServerSession?.connect()
                }
                return true
            case .cancel:
                return false
            }
        } else {
            return true
        }
    }

    func urlValidation(urls: [String]) async -> Bool {
        let whitelistUrls = jade.blockstreamUrls + customWhitelistUrls + persistCustomWhitelistUrls
        let whitelistDomains = whitelistUrls.compactMap { domain(from: $0) }
        let domains = urls.filter { !$0.isEmpty }
            .compactMap { domain(from: $0) }
        let isUrlSafe = domains.allSatisfy { domain in whitelistDomains.contains(domain) }
        if isUrlSafe {
            return true
        }
        switch await showUrlValidationWarning(domains: domains) {
        case .continue: return true
        case .cancel: return false
        }
    }

    func httpRequest(params: [String: Any]) async -> [String: Any]? {
        var network: NetworkSecurityCase? = .bitcoinSS
        try? await connectPinServer(testnet: network?.testnet ?? false)
        return self.pinServerSession?.httpRequest(params: params)
    }
}
