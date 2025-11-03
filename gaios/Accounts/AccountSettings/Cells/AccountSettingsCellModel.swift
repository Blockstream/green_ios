import Foundation
import UIKit
import core

enum AccountSettingsType {
    case rename(current: String)
    case watchonly
    case archive
}
class AccountSettingsCellModel {
    var type: AccountSettingsType
    var isFunded: Bool

    init(type: AccountSettingsType, isfunded: Bool) {
        self.type = type
        self.isFunded = isfunded
    }
    var title: String {
        switch self.type {
        case .rename(let current):
            return "id_rename".localized + " \"\(current)\""
        case .watchonly:
            return "id_watchonly".localized
        case .archive:
            return "id_archive".localized
        }
    }
}
