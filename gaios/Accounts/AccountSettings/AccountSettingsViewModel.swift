import Foundation
import UIKit
import gdk
import core

class AccountSettingsViewModel {

    var title: String
    var actions: [AccountSettingsType]
    var isFunded: Bool

    init(title: String,
         actions: [AccountSettingsType],
         isFunded: Bool
    ) {
        self.title = title
        self.actions = actions
        self.isFunded = isFunded
    }

    var cellModels: [AccountSettingsCellModel] {
        var list = [AccountSettingsCellModel]()
        for action in actions {
            list.append(AccountSettingsCellModel(type: action, isfunded: isFunded))
        }
        return list
    }
}
