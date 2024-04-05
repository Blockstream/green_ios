import Foundation
import gdk

public enum MnemonicSize: Int {
    case _12 = 12
    case _24 = 24
}

public struct OnBoardParams: Codable {
    public var testnet: Bool?
    public var walletName: String?
    public var mnemonic: String?
    public var mnemomicPassword: String?
    public var mnemonicSize = MnemonicSize._12.rawValue
    public var accountId: String?
    public var xpubHashId: String?
    public var restoreSuccess: Bool?

    public static var shared = OnBoardParams()

    public func toAccount() -> Account {
        let network: NetworkSecurityCase = testnet ?? false ? .testnetSS : .bitcoinSS
        return Account(id: accountId ?? UUID().uuidString,
                       name: walletName ?? "",
                       network: network,
                       xpubHashId: xpubHashId ?? "")
    }
    public init(testnet: Bool? = nil, walletName: String? = nil, mnemonic: String? = nil, mnemomicPassword: String? = nil, mnemonicSize: Int = MnemonicSize._12.rawValue, accountId: String? = nil, xpubHashId: String? = nil, restoreSuccess: Bool? = nil) {
        self.testnet = testnet
        self.walletName = walletName
        self.mnemonic = mnemonic
        self.mnemomicPassword = mnemomicPassword
        self.mnemonicSize = mnemonicSize
        self.accountId = accountId
        self.xpubHashId = xpubHashId
        self.restoreSuccess = restoreSuccess
    }
}
