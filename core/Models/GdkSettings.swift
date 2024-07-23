import Foundation
import gdk

public struct GdkSettings: Codable {

    enum CodingKeys: String, CodingKey {
        case tor
        case proxy
        case socks5Hostname = "socks5_hostname"
        case socks5Port = "socks5_port"
        case spvEnabled = "spv_enabled"
        case personalNodeEnabled = "personal_node_enabled"
        case btcElectrumSrv = "btc_electrum_srv"
        case liquidElectrumSrv = "liquid_electrum_srv"
        case testnetElectrumSrv = "testnet_electrum_srv"
        case liquidTestnetElectrumSrv = "liquid_testnet_electrum_srv"
        case electrumTls = "electrum_tls"
    }
    public let tor: Bool?
    public let proxy: Bool?
    public let socks5Hostname: String?
    public let socks5Port: String?
    public let spvEnabled: Bool?
    public let personalNodeEnabled: Bool?
    public let btcElectrumSrv: String?
    public let liquidElectrumSrv: String?
    public let testnetElectrumSrv: String?
    public let liquidTestnetElectrumSrv: String?
    public let electrumTls: Bool?

    public static let btcElectrumSrvDefaultEndPoint = "blockstream.info:700"
    public static let liquidElectrumSrvDefaultEndPoint = "blockstream.info:995"
    public static let testnetElectrumSrvDefaultEndPoint = "blockstream.info:993"
    public static let liquidTestnetElectrumSrvDefaultEndPoint = "blockstream.info:465"

    public init(tor: Bool?, proxy: Bool?, socks5Hostname: String?, socks5Port: String?, spvEnabled: Bool?, personalNodeEnabled: Bool?, btcElectrumSrv: String?, liquidElectrumSrv: String?, testnetElectrumSrv: String?, liquidTestnetElectrumSrv: String?, electrumTls: Bool?) {
        self.tor = tor
        self.proxy = proxy
        self.socks5Hostname = socks5Hostname
        self.socks5Port = socks5Port
        self.spvEnabled = spvEnabled
        self.personalNodeEnabled = personalNodeEnabled
        self.btcElectrumSrv = btcElectrumSrv
        self.liquidElectrumSrv = liquidElectrumSrv
        self.testnetElectrumSrv = testnetElectrumSrv
        self.liquidTestnetElectrumSrv = liquidTestnetElectrumSrv
        self.electrumTls = electrumTls
    }

    public static func read() -> GdkSettings? {
        let value = UserDefaults.standard.value(forKey: "network_settings") as? [String: Any] ?? [:]
        return GdkSettings.from(value) as? GdkSettings
    }

    public func write() {
        let newValue = self.toDict()
        UserDefaults.standard.set(newValue, forKey: "network_settings")
        UserDefaults.standard.synchronize()
    }

    public func toNetworkParams(_ network: String) -> NetworkSettings {
        let gdkSettings = GdkSettings.read()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? CVarArg ?? ""
        let proxyURI = String(format: "socks5://%@:%@/", gdkSettings?.socks5Hostname ?? "", gdkSettings?.socks5Port ?? "")
        let gdkNetwork = GdkNetworks.shared.get(network: network)
        let electrumUrl: String? = {
            if let srv = gdkSettings?.btcElectrumSrv, gdkNetwork.mainnet && !gdkNetwork.liquid && !srv.isEmpty {
                return srv
            } else if let srv = gdkSettings?.testnetElectrumSrv, !gdkNetwork.mainnet && !gdkNetwork.liquid && !srv.isEmpty {
                return srv
            } else if let srv = gdkSettings?.liquidElectrumSrv, gdkNetwork.mainnet && gdkNetwork.liquid && !srv.isEmpty {
                return srv
            } else if let srv = gdkSettings?.liquidTestnetElectrumSrv, !gdkNetwork.mainnet && gdkNetwork.liquid && !srv.isEmpty {
                return srv
            } else {
                return nil
            }
        }()
        let isDefaultEletrumEndpoint = [
            GdkSettings.btcElectrumSrvDefaultEndPoint,
            GdkSettings.liquidElectrumSrvDefaultEndPoint,
            GdkSettings.testnetElectrumSrvDefaultEndPoint,
            GdkSettings.liquidTestnetElectrumSrvDefaultEndPoint,
            "", nil].contains(electrumUrl)
        let electrumTls = isDefaultEletrumEndpoint ? nil : gdkSettings?.electrumTls
        return NetworkSettings(
            name: network,
            useTor: gdkSettings?.tor ?? false,
            proxy: (gdkSettings?.proxy ?? false) ? proxyURI : nil,
            userAgent: String(format: "green_ios_%@", version),
            spvEnabled: (gdkSettings?.spvEnabled ?? false) && !gdkNetwork.liquid,
            electrumUrl: gdkSettings?.personalNodeEnabled ?? false ? electrumUrl : nil,
            electrumOnionUrl: gdkSettings?.personalNodeEnabled ?? false ? electrumUrl : nil,
            electrumTls: gdkSettings?.personalNodeEnabled ?? false ? electrumTls : nil
        )
    }

    public static func enableTor() {
        let current = AppSettings.shared.gdkSettings

        let new = GdkSettings(
            tor: true,
            proxy: current?.proxy,
            socks5Hostname: current?.socks5Hostname,
            socks5Port: current?.socks5Port,
            spvEnabled: current?.spvEnabled,
            personalNodeEnabled: current?.personalNodeEnabled,
            btcElectrumSrv: current?.btcElectrumSrv,
            liquidElectrumSrv: current?.liquidElectrumSrv,
            testnetElectrumSrv: current?.testnetElectrumSrv,
            liquidTestnetElectrumSrv: current?.liquidTestnetElectrumSrv,
            electrumTls: current?.electrumTls
        )

        AppSettings.shared.gdkSettings = new
    }
}
