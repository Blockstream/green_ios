import Foundation
import UIKit

class EditScreenLockSettings: UIViewController {
    @IBOutlet weak var bioAuthLabel: UILabel!
    @IBOutlet weak var bioSwitch: UISwitch!
    @IBOutlet weak var pinSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()

        let biometryType = AuthenticationTypeHandler.biometryType
        if biometryType == .faceID {
            bioAuthLabel.text = NSLocalizedString("id_face_id", comment: "")
        } else if biometryType == .touchID {
            bioAuthLabel.text = NSLocalizedString("id_touch_id", comment: "")
        } else {
            bioAuthLabel.text = NSLocalizedString("id_touchface_id_not_available", comment: "")
            bioSwitch.isEnabled = false
        }
        title = NSLocalizedString("id_screen_lock", comment: "")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        updateValues()
    }

    func updateValues() {
        guard let settings = getGAService().getSettings() else { return }
        let screenlock = settings.getScreenLock()
        if screenlock == .None {
            bioSwitch.isOn = false
            bioSwitch.isEnabled = true
            pinSwitch.isOn = false
            pinSwitch.isEnabled = true
        } else if screenlock == .All {
            bioSwitch.isOn = true
            bioSwitch.isEnabled = false
            pinSwitch.isOn = true
            pinSwitch.isEnabled = false
        } else if screenlock == .FaceID || screenlock == .TouchID {
            bioSwitch.isOn = true
            bioSwitch.isEnabled = false
            pinSwitch.isOn = false
            pinSwitch.isEnabled = true
        } else if screenlock == .Pin {
            bioSwitch.isOn = false
            bioSwitch.isEnabled = true
            pinSwitch.isOn = true
            pinSwitch.isEnabled = false
        }
    }

    @IBAction func bioAuthSwitched(_ sender: UISwitch) {
        if (!sender.isOn) {
            AppDelegate.removeBioKeychainData()
            self.updateValues()
        } else {
            let password = String.random(length: 14)
            let deviceid = String.random(length: 14)
            let mnemonics = getAppDelegate().getMnemonicWordsString()
            wrap {
                try getSession().setPin(mnemonic: mnemonics!, pin: password, device: deviceid) }
            .done { result in
                guard let result = result else {
                    return
                }
                let network = getNetworkSettings().network
                try AuthenticationTypeHandler.addBiometryType(data: result, extraData: password, forNetwork: network)
            }.catch { error in
                print("setPin failed")
            }
          }
    }

    @IBAction func pinSwitched(_ sender: UISwitch) {
        if (sender.isOn) {
            self.performSegue(withIdentifier: "pinConfirm", sender: "set")
        } else {
            self.performSegue(withIdentifier: "pinConfirm", sender: "remove")
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? PinLoginViewController {
            let todo = sender as! String
            if (todo == "set") {
                nextController.editPinMode = true
                nextController.setPinMode = true
            }
        }
    }
}
