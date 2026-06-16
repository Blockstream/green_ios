import Foundation
import UIKit
import core


struct DialogSignViewModel {

    var subaccount: Account
    var address: String
    var isHW: Bool { WalletsStorage.shared.current?.isHW ?? false }
    
    @MainActor var session: SessionManager? {
        if isHW && BleHwManager.shared.walletManager != nil {
            if BleHwManager.shared.isConnected() {
                return BleHwManager.shared.walletManager?
                    .gdkAccountBackendOrNil(subaccount)?.session
            }
        }
        return WalletManager.current?.gdkAccountBackendOrNil(subaccount)?.session
    }

    func sign(message: String) async throws -> String? {
        let params = SignMessageParams(address: address, message: message)
        let res = try await session?.signMessage(params)
        return res?.signature
    }
}
