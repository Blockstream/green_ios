import Foundation
import UIKit
import core
import gdk

struct DialogSignViewModel {

    var subaccount: WalletItem
    var address: String
    var isHW: Bool { WalletManager.current?.isHW ?? false }
    
    var session: SessionManager? {
        if isHW && BleHwManager.shared.walletManager != nil {
            if BleHwManager.shared.isConnected() {
                return BleHwManager.shared.walletManager?.getSession(for: subaccount)
            }
        }
        return WalletManager.current?.getSession(for: subaccount)
    }

    func sign(message: String) async throws -> String? {
        let params = SignMessageParams(address: address, message: message)
        let res = try await session?.signMessage(params)
        return res?.signature
    }
}
