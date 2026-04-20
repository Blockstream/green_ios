import Foundation
import UIKit
import gdk
import core

class AccountSettingsViewModel {

    var title: String
    var actions: [AccountSettingsType]
    var isFunded: Bool
    var isArchivable: Bool

    init(title: String,
         actions: [AccountSettingsType],
         isFunded: Bool,
         isArchivable: Bool
    ) {
        self.title = title
        self.actions = actions
        self.isFunded = isFunded
        self.isArchivable = isArchivable
    }

    var cellModels: [AccountSettingsCellModel] {
        var list = [AccountSettingsCellModel]()
        for action in actions {
            list.append(AccountSettingsCellModel(type: action, isfunded: isFunded, isArchivable: isArchivable))
        }
        return list
    }
}
