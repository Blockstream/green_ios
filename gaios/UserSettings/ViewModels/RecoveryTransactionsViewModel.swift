import Foundation
import UIKit
import core
import gdk

class RecoveryTransactionsViewModel {

    var session: SessionManager

    init(session: SessionManager) {
        self.session = session
    }

    func getTwoFactorItemEmail() async throws -> TwoFactorItem? {
        if !session.logged {
            return nil
        }
        if let twoFactorConfig = try await session.loadTwoFactorConfig() {
            return TwoFactorItem(name: "id_email".localized,
                                 enabled: twoFactorConfig.email.enabled,
                                 confirmed: twoFactorConfig.email.confirmed,
                                 maskedData: twoFactorConfig.email.data,
                                 type: TwoFactorType.email)
        }
        return nil
    }

    func setEmail(session: SessionManager, email: String, isSetRecovery: Bool) async throws {
        let config = TwoFactorConfigItem(enabled: isSetRecovery ? false : true, confirmed: true, data: email)
        let params = ChangeSettingsTwoFactorParams(method: .email, config: config)
        try await session.changeSettingsTwoFactor(params)
        _ = try await session.loadTwoFactorConfig()
    }
}
