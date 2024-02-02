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
}
