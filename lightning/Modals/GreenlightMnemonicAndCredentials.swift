import Foundation
import GreenlightSDK

public struct GreenlightMnemonicAndCredentials: Codable {
    let mnemonic: String
    let credentials: Data?
    public init(mnemonic: String, credentials: Data? = nil) {
        self.mnemonic = mnemonic
        self.credentials = credentials
    }
}
