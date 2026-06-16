import Foundation
import GreenlightSDK

public struct GreenlightMnemonicAndCredentials: Codable {
    public let mnemonic: String
    public let credentials: Data?
    public init(mnemonic: String, credentials: Data? = nil) {
        self.mnemonic = mnemonic
        self.credentials = credentials
    }
}
