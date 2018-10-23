import Foundation
import UIKit

class TwoFactorWarningSettings: UIViewController {

    @IBOutlet weak var noFactorLabel: UILabel!
    @IBOutlet weak var oneFactorLabel: UILabel!
    @IBOutlet weak var noFactorSwitch: UISwitch!
    @IBOutlet weak var oneFactorSwitch: UISwitch!
    @IBOutlet weak var topLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let settings = SettingsStore.shared.getTwoFactorWarning()
        noFactorSwitch.isOn = settings.0
        oneFactorSwitch.isOn = settings.1
        topLabel.text = NSLocalizedString("ptwo_factor_warning", comment: "")
        noFactorLabel.text = NSLocalizedString("pno_two_factor_enabled", comment: "")
        oneFactorLabel.text = NSLocalizedString("ponly_one_two_factor_enabled", comment: "")
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func noFactorSwitched(_ sender: UISwitch) {
        SettingsStore.shared.setTwoFactorWarning(noFactor: noFactorSwitch.isOn, oneFactor: oneFactorSwitch.isOn)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "twoFactorWarningChanged"), object: nil, userInfo: nil)
    }

    @IBAction func oneFactorSwitch(_ sender: Any) {
        SettingsStore.shared.setTwoFactorWarning(noFactor: noFactorSwitch.isOn, oneFactor: oneFactorSwitch.isOn)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "twoFactorWarningChanged"), object: nil, userInfo: nil)
    }

}
