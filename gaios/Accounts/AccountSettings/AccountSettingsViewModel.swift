import Foundation
import UIKit
import gdk
import core

class AccountSettingsViewModel {

    var title: String
    var actions: [AccountSettingsType]

    init(title: String,
         actions: [AccountSettingsType]
    ) {
        self.title = title
        self.actions = actions
    }

    var cellModels: [AccountSettingsCellModel] {
        var list = [AccountSettingsCellModel]()
        for action in actions {
            list.append(AccountSettingsCellModel(type: action))
        }
        return list
    }
}
