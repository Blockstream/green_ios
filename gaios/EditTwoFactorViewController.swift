import Foundation
import UIKit

class EditTwoFactorViewController: UIViewController, TwoFactorCallDelegate {

    @IBOutlet weak var emailSwitch: UISwitch!
    @IBOutlet weak var smsSwitch: UISwitch!
    @IBOutlet weak var phoneSwitch: UISwitch!
    @IBOutlet weak var gauth: UISwitch!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var smsLabel: UILabel!
    @IBOutlet weak var phoneCallLabel: UILabel!
    @IBOutlet weak var gauthLabel: UILabel!
    var twoFactorController: UIViewController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = NSLocalizedString("id_twofactor_settings", comment: "")
        emailLabel.text = NSLocalizedString("id_email", comment: "")
        smsLabel.text = NSLocalizedString("id_sms", comment: "")
        phoneCallLabel.text = NSLocalizedString("id_phone_call", comment: "")
        gauthLabel.text = NSLocalizedString("id_google_authenticator", comment: "")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        emailSwitch.isOn = AccountStore.shared.isEmailEnabled()
        smsSwitch.isOn = AccountStore.shared.isSMSEnabled()
        phoneSwitch.isOn = AccountStore.shared.isPhoneEnabled()
        gauth.isOn = AccountStore.shared.isGauthEnabled()
    }

    @IBAction func emailSwitched(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "email", sender: nil)
        } else {
            let call = AccountStore.shared.disableEmailTwoFactor()
            requestCode(twoFactor: call)
        }

    }

    @IBAction func smsSwitched(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "phone", sender: "sms")
        } else {
            let call = AccountStore.shared.disableSMSTwoFactor()
            requestCode(twoFactor: call)
        }
    }

    @IBAction func phoneSwitched(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "phone", sender: "phone")
        } else {
            let call = AccountStore.shared.disablePhoneCallTwoFactor()
            requestCode(twoFactor: call)
        }
    }

    @IBAction func gauthSwithed(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "gauth", sender: nil)
        } else {
            let call = AccountStore.shared.disableGauthTwoFactor()
            requestCode(twoFactor: call)
        }
    }

    func requestCode(twoFactor: TwoFactorCall?) {
        if (twoFactor == nil) {
            return
        }
        do {
            let resultHelper = TwoFactorCallHelper(twoFactor!)
            resultHelper.delegate = self
            try resultHelper.resolve()
        } catch {
            print(error)
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? TwoFactorSlectorViewController {
            nextController.twoFactor = sender as! TwoFactorCall
        } else if let nextController = segue.destination as? SetPhoneViewController {
            if (sender as! String == "sms") {
                nextController.sms = true
            } else {
                nextController.phoneCall = true
            }
            nextController.onboarding = false
        } else if let nextController = segue.destination as? SetEmailViewController {
            nextController.onboarding = false
        } else if let nextController = segue.destination as? SetGauthViewController {
            nextController.onboarding = false
        }
    }

    func onResolve(_ sender: TwoFactorCallHelper) {
        let alert = TwoFactorCallHelper.CodePopup(sender)
        presetTwoFactorController(c: alert)
    }

    func onRequest(_ sender: TwoFactorCallHelper) {
        let selector = TwoFactorCallHelper.MethodPopup(sender)
        presetTwoFactorController(c: selector)
    }

    func presetTwoFactorController(c: UIViewController) {
        if (twoFactorController != nil) {
            twoFactorController?.dismiss(animated: false, completion: {
                self.twoFactorController = c
                self.present(c, animated: true, completion: nil)
            })
        } else {
            twoFactorController = c
            self.present(c, animated: true, completion: nil)
        }
    }

    func onDone(_ sender: TwoFactorCallHelper) {
        if (twoFactorController != nil) {
            twoFactorController?.dismiss(animated: false, completion: nil)
        }
        self.navigationController?.popToRootViewController(animated: true)
    }

    func onError(_ sender: TwoFactorCallHelper, text: String) {
        if (twoFactorController != nil) {
            twoFactorController?.dismiss(animated: false, completion: nil)
        }
    }
}
