import Foundation
import UIKit

class ToggleSettingsViewController: UIViewController {

    var SettingsName: String = ""
    var settings: SettingsItem? = nil
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var statusSwitch: UISwitch!

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        topLabel.text = settings?.text
        let bottomText = String(format: "Enable %@", (settings?.text)!)
        bottomLabel.text = bottomText
        statusSwitch.isOn = SettingsStore.shared.getNLocktimeEmailsEnabled()
    }

    @IBAction func statusChanged(_ sender: UISwitch) {
        SettingsStore.shared.setNLocktimeEmailsEnabled(enabled: sender.isOn)

    }

}
