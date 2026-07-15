import Foundation
import greenaddress

public class Gdk {
    static public let shared = Gdk()
    public let networks: GdkNetworks
    public let config: GdkInit

    init() {
        networks = try! Gdk.getNetworks()!
        config = GdkInit.defaults()
        try! gdkInit(config: config)
    }

    public func generateMnemonic12() async throws -> String {
        try greenaddress.generateMnemonic12()
    }
    public func generateMnemonic24() async throws -> String {
        try greenaddress.generateMnemonic()
    }
    public func validateMnemonic(mnemonic: String) async throws -> Bool {
        try greenaddress.validateMnemonic(mnemonic: mnemonic)
    }

    func gdkInit(config: GdkInit) throws {
        _ = try greenaddress.gdkInit(config: config.asDictionary())
    }

    static func getNetworks() throws -> GdkNetworks? {
        try greenaddress.getNetworks()?.decode(GdkNetworks.self)
    }

    func hasGdkCache(walletHashId: String) -> Bool {
        if let datadir = config.datadir, !datadir.isEmpty {
            let dir = "\(datadir)/state/\(walletHashId)"
            return FileManager.default.fileExists(atPath: dir)
        }
        return false
    }

    func removeGdkCache(walletHashId: String) -> Bool {
        if let datadir = config.datadir, !datadir.isEmpty {
            let dir = "\(datadir)/state/\(walletHashId)"
            try? FileManager.default.removeItem(atPath: dir)
            return true
        }
        return false
    }

    public static func getWalletIdentifier(gdkNetwork: String, credentials: Credentials) throws -> WalletIdentifier {
        let session = GDKSession()
        let res = try session.getWalletIdentifier(
            net_params: ["name": gdkNetwork],
            details: credentials.asDictionary())
        guard let res else {
            throw GaError.GenericError("Failed to get wallet identifier")
        }
        return try res.decode(WalletIdentifier.self)
    }
}

