import Foundation
import UIKit

class EditScreenLockSettings: UIViewController {
    @IBOutlet weak var bioAuthLabel: UILabel!
    @IBOutlet weak var bioSwitch: UISwitch!
    @IBOutlet weak var pinSwitch: UISwitch!
    let bioAuth = BiometricAuthentication()

    override func viewDidLoad() {
        super.viewDidLoad()
        if bioAuth.canEvaluatePolicy() {
            if bioAuth.biometricType() == .faceID {
                bioAuthLabel.text = NSLocalizedString("id_face_id", comment: "")
            } else if bioAuth.biometricType() == .touchID {
                bioAuthLabel.text = NSLocalizedString("id_touch_id", comment: "")
            } else {
                bioAuthLabel.text = NSLocalizedString("id_touchface_id_not_available", comment: "")
                bioSwitch.isUserInteractionEnabled = false
            }
        } else {
            bioAuthLabel.text = NSLocalizedString("id_touchface_id_not_available", comment: "")
            bioSwitch.isUserInteractionEnabled = false
        }
        title = NSLocalizedString("id_screen_lock", comment: "")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        updateValues()
    }

    func updateValues() {
        let settings = SettingsStore.shared.getScreenLockSetting()
        if(settings == ScreenLock.None) {
            bioSwitch.isOn = false
            pinSwitch.isOn = false
        } else if (settings == ScreenLock.all) {
            bioSwitch.isOn = true
            pinSwitch.isOn = true
        } else if (settings == ScreenLock.FaceID || settings == ScreenLock.TouchID) {
            bioSwitch.isOn = true
            pinSwitch.isOn = false
        } else if (settings == ScreenLock.Pin) {
            bioSwitch.isOn = false
            pinSwitch.isOn = true
        }
    }

    @IBAction func bioAuthSwitched(_ sender: UISwitch) {
        if (!sender.isOn) {
            try! AppDelegate.removeBioKeychainData()
            SettingsStore.shared.setScreenLockSettings()
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
                let succeeded = KeychainHelper.addBiometryType(data: result, extraData: password, forNetwork: network)
                guard succeeded else {
                    return
                }
                SettingsStore.shared.setScreenLockSettings()
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
            if (todo == "remove") {
                nextController.removePinMode = true
                nextController.editPinMode = true
            } else if (todo == "set") {
                nextController.editPinMode = true
                nextController.setPinMode = true
            }
        }
    }
}
