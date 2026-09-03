import Foundation
import core

struct Set2FAViewModel {

    let mainWallet: Wallet
    let manager: WalletManager
    let networkId: NetworkId
    let method: TwoFactorType
    var isSetRecovery: Bool = false
    var isSmsBackup: Bool = false

    var backend: GdkNetworkBackend? {
        manager.gdkNetworkBackendOrNil(networkId)
    }

    var sms: Bool { method == .sms }
    var phoneCall: Bool { method == .phone }

    func changeSettingsTwoFactor(_ param: ChangeSettingsTwoFactorParams) async throws {
        try await backend?.changeSettingsTwoFactor(param)
    }

}
