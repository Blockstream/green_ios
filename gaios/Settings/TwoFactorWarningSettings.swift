import Foundation
import UIKit

class TwoFactorWarningSettings: UIViewController {

    @IBOutlet weak var noFactorLabel: UILabel!
    @IBOutlet weak var oneFactorLabel: UILabel!
    @IBOutlet weak var noFactorSwitch: UISwitch!
    @IBOutlet weak var oneFactorSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
// FIXME: Remove this preference completely; 2fa notifications should not be disableable
//        let settings = SettingsStore.shared.getTwoFactorWarning()
//        noFactorSwitch.isOn = settings.0
//        oneFactorSwitch.isOn = settings.1
//        title = NSLocalizedString("id_twofactor_warning", comment: "")
//        noFactorLabel.text = NSLocalizedString("id_no_twofactor_enabled", comment: "")
//        oneFactorLabel.text = NSLocalizedString("id_only_one_twofactor_enabled", comment: "")
    }

    @IBAction func noFactorSwitched(_ sender: UISwitch) {
//        SettingsStore.shared.setTwoFactorWarning(noFactor: noFactorSwitch.isOn, oneFactor: oneFactorSwitch.isOn)
//        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "twoFactorWarningChanged"), object: nil, userInfo: nil)
    }

    @IBAction func oneFactorSwitch(_ sender: Any) {
//        SettingsStore.shared.setTwoFactorWarning(noFactor: noFactorSwitch.isOn, oneFactor: oneFactorSwitch.isOn)
//        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "twoFactorWarningChanged"), object: nil, userInfo: nil)
    }

}
