import NVActivityIndicatorView
import PromiseKit
import UIKit

class EditScreenLockSettings: UIViewController, NVActivityIndicatorViewable {
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
        guard let settings = getGAService().getSettings() else {
            return
        }
        let screenlock = settings.getScreenLock()
        if screenlock == .None {
            bioSwitch.isOn = false
            pinSwitch.isOn = false
        } else if screenlock == .All {
            bioSwitch.isOn = true
            pinSwitch.isOn = true
        } else if screenlock == .FaceID || screenlock == .TouchID {
            bioSwitch.isOn = true
            pinSwitch.isOn = false
        } else if screenlock == .Pin {
            bioSwitch.isOn = false
            pinSwitch.isOn = true
        }
    }

    func onAuthRemoval(_ sender: UISwitch, _ completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: NSLocalizedString("id_warning", comment: ""), message: NSLocalizedString("id_deleting_your_pin_will_remove", comment: ""), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { _ in
            sender.isOn = true
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_next", comment: ""), style: .default) { _ in
            completionHandler()
        })
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }

    @IBAction func bioAuthSwitched(_ sender: UISwitch) {
        if !sender.isOn {
            onAuthRemoval(sender) {
                removeBioKeychainData()
            }
        } else {
            let bgq = DispatchQueue.global(qos: .background)
            firstly {
                startAnimating()
                return Guarantee()
            }.compactMap(on: bgq) {
                let password = String.random(length: 14)
                let deviceid = String.random(length: 14)
                let mnemonics = getAppDelegate().getMnemonicWordsString()
                return (try getSession().setPin(mnemonic: mnemonics!, pin: password, device: deviceid), password) as? ([String : Any], String)
            }.done { (data: [String: Any], password: String) -> Void in
                let network = getNetwork()
                try AuthenticationTypeHandler.addBiometryType(data: data, extraData: password, forNetwork: network)
            }.catch { _ in
            }.finally {
                self.stopAnimating()
            }
        }
    }

    @IBAction func pinSwitched(_ sender: UISwitch) {
        if sender.isOn {
            self.performSegue(withIdentifier: "restorePin", sender: nil)
        } else {
            onAuthRemoval(sender) {
                removePinKeychainData()
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? PinLoginViewController {
            nextController.editPinMode = true
            nextController.setPinMode = true
        }
    }
}
