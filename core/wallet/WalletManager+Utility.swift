import Foundation
import greenaddress

extension WalletManager {
    public func bcurEncode(params: BcurEncodeParams) async throws -> BcurEncodedData? {
        try await prominentNetworkBackend?.session.bcurEncode(params: params)
    }

    public func bcurDecode(params: BcurDecodeParams, bcurResolver: BcurResolver) async throws -> BcurDecodedData? {
        try await prominentNetworkBackend?.session.bcurDecode(params: params, bcurResolver: bcurResolver)
    }

    public func jadeBip8539Request(index: UInt32) async throws -> (Data?, BcurEncodedData?) {
        let privateKey = createEcKey()
        let params = BcurEncodeParams(
            urType: "jade-bip8539-request",
            numWords: 12,
            index: index,
            privateKey: privateKey?.hex
        )
        let data = try await bcurEncode(params: params)
        return (privateKey, data)
    }

    public func jadeBip8539Reply(privateKey: Data, publicKey: Data, encrypted: Data) async -> String? {
        return Wally.bip85FromJade(
            privateKey: [UInt8](privateKey),
            publicKey: [UInt8](publicKey),
            label: "bip85_bip39_entropy",
            payload: [UInt8](encrypted))
    }

    public func createEcKey() -> Data? {
        var privateKey: Data?
        repeat {
            privateKey = secureRandomData(count: Wally.EC_PRIVATE_KEY_LEN)
        } while(privateKey != nil && !Wally.ecPrivateKeyVerify(privateKey: [UInt8](privateKey!)))
        return privateKey
    }

    public func deriveBoltzCredentials(from credentials: Credentials) throws -> Credentials {
        guard let mnemonic = credentials.mnemonic else {
            throw GaError.GenericError("No such mnemonic")
        }
        let bip85Key = Wally.bip85FromMnemonic(
            mnemonic: mnemonic,
            passphrase: credentials.bip39Passphrase,
            isTestnet: false,
            index: LwkBoltzBackend.BOLTZ_BIP85_INDEX)
        return Credentials(
            mnemonic: bip85Key,
            bip39Passphrase: credentials.bip39Passphrase)
    }
    public func deriveLightningCredentials(from credentials: Credentials) throws -> Credentials {
        guard let mnemonic = credentials.mnemonic else {
            throw GaError.GenericError("No such mnemonic")
        }
        let bip85Key = Wally.bip85FromMnemonic(
            mnemonic: mnemonic,
            passphrase: credentials.bip39Passphrase,
            isTestnet: false,
            index: 0)
        return Credentials(
            mnemonic: bip85Key,
            bip39Passphrase: credentials.bip39Passphrase)
    }

    public func getWalletIdentifier(
        network: GdkNetwork? = nil,
        credentials: Credentials,
    ) async throws -> WalletIdentifier? {
        let network = network ?? prominentNetwork
        return try prominentNetworkBackend?.session
            .getWalletIdentifier(
                gdkNetwork: network.network,
                credentials: credentials
            )
    }

    public func removeDatadir(_ dir: String) throws {
        try FileManager.default.removeItem(atPath: dir)
    }
}
