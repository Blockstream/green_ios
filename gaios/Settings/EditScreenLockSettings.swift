import NVActivityIndicatorView
import PromiseKit
import UIKit

class EditScreenLockSettings: UIViewController, NVActivityIndicatorViewable {
    @IBOutlet weak var bioAuthLabel: UILabel!
    @IBOutlet weak var bioSwitch: UISwitch!
    @IBOutlet weak var pinSwitch: UISwitch!
    @IBOutlet weak var helpLabel: UILabel!

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
        helpLabel.text = ""
        let screenlock = settings.getScreenLock()
        if GreenAddressService.restoreFromMnemonics && isPinEnabled(network: getNetwork()) {
            bioSwitch.isOn = false
            bioSwitch.isEnabled = false
            pinSwitch.isOn = false
            pinSwitch.isEnabled = false
            helpLabel.numberOfLines = 0
            helpLabel.text = String(format: NSLocalizedString("id_there_is_already_a_pin_set_for", comment: ""), getNetwork())
        } else if screenlock == .None {
            bioSwitch.isOn = false
            pinSwitch.isOn = false
        } else if screenlock == .All {
            bioSwitch.isOn = true
            pinSwitch.isOn = true
        } else if screenlock == .FaceID || screenlock == .TouchID {
            // this should never happen
            NSLog("no pin exists but faceid/touchid is enabled" )
            bioSwitch.isOn = true
            pinSwitch.isOn = false
        } else if screenlock == .Pin {
            bioSwitch.isOn = false
            pinSwitch.isOn = true
        }
    }

    func onAuthRemoval(_ sender: UISwitch, _ completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: NSLocalizedString("id_warning", comment: ""), message: NSLocalizedString(sender == pinSwitch ? "id_deleting_your_pin_will_remove" : "id_your_pin_or_your_mnemonic_will", comment: ""), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { _ in
            DispatchQueue.main.async {
                sender.setOn(true, animated: true)
            }
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_ok", comment: ""), style: .default) { _ in
            completionHandler()
        })
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }

    func verifyAuth(message: String, _ sender: UISwitch) {
        let alert = UIAlertController(title: NSLocalizedString("id_warning", comment: ""), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_ok", comment: ""), style: .default) { _ in })
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
            sender.setOn(!sender.isOn, animated: true)
        }
    }

    @IBAction func bioAuthSwitched(_ sender: UISwitch) {
        if !AuthenticationTypeHandler.findAuth(method: AuthenticationTypeHandler.AuthKeyPIN, forNetwork: getNetwork()) {
            verifyAuth(message: NSLocalizedString("id_please_enable_pin", comment: ""), sender)
        } else if !sender.isOn {
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
                let mnemonics = try getSession().getMnemmonicPassphrase(password: "")
                return (try getSession().setPin(mnemonic: mnemonics, pin: password, device: deviceid), password) as? ([String : Any], String)
            }.done { (data: [String: Any], password: String) -> Void in
                try AuthenticationTypeHandler.addBiometryType(data: data, extraData: password, forNetwork: getNetwork())
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
            if AuthenticationTypeHandler.findAuth(method: AuthenticationTypeHandler.AuthKeyBiometric, forNetwork: getNetwork()) {
                verifyAuth(message: NSLocalizedString("id_please_disable_biometric", comment: ""), sender)
            } else {
                onAuthRemoval(sender) {
                    removePinKeychainData()
                }
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
