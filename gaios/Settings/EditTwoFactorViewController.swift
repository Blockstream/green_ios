import Foundation
import UIKit
import NVActivityIndicatorView

class EditTwoFactorViewController: UIViewController, NVActivityIndicatorViewable, TwoFactorCallDelegate {

    @IBOutlet weak var emailSwitch: UISwitch!
    @IBOutlet weak var smsSwitch: UISwitch!
    @IBOutlet weak var phoneSwitch: UISwitch!
    @IBOutlet weak var gauth: UISwitch!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var smsLabel: UILabel!
    @IBOutlet weak var phoneCallLabel: UILabel!
    @IBOutlet weak var gauthLabel: UILabel!
    var errorLabel: UIErrorLabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("id_twofactor_settings", comment: "")
        emailLabel.text = NSLocalizedString("id_email", comment: "")
        smsLabel.text = NSLocalizedString("id_sms", comment: "")
        phoneCallLabel.text = NSLocalizedString("id_phone_call", comment: "")
        gauthLabel.text = NSLocalizedString("id_google_authenticator", comment: "")
        errorLabel = UIErrorLabel(self.view)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        emailSwitch.isOn = AccountStore.shared.isEmailEnabled()
        smsSwitch.isOn = AccountStore.shared.isSMSEnabled()
        phoneSwitch.isOn = AccountStore.shared.isPhoneEnabled()
        gauth.isOn = AccountStore.shared.isGauthEnabled()
    }

    func disable(_ method: String) {
        if self.isAnimating {
            return
        }
        errorLabel.isHidden = true
        self.startAnimating(CGSize(width: 30, height: 30),
                            type: NVActivityIndicatorType.ballRotateChase)
        let dict = ["enabled": false] as [String : Any]
        DispatchQueue.global(qos: .background).async {
            wrap {
                try getSession().changeSettingsTwoFactor(method: method, details: dict)
            }.done { (result: TwoFactorCall) in
                try TwoFactorCallHelper(result, delegate: self).resolve()
            }.catch { error in
                DispatchQueue.main.async {
                    self.onError(nil, text: error.localizedDescription)
                }
            }
        }
    }

    func onResolve(_ sender: TwoFactorCallHelper?) {
        let alert = TwoFactorCallHelper.CodePopup(sender!)
        self.present(alert, animated: true, completion: nil)
    }

    func onRequest(_ sender: TwoFactorCallHelper?) {
        let alert = TwoFactorCallHelper.MethodPopup(sender!)
        self.present(alert, animated: true, completion: nil)
    }

    func onDone(_ sender: TwoFactorCallHelper?) {
        self.stopAnimating()
        viewWillAppear(false)
    }

    func onError(_ sender: TwoFactorCallHelper?, text: String) {
        self.stopAnimating()
        errorLabel.isHidden = false
        errorLabel.text = NSLocalizedString(text, comment: "")
        viewWillAppear(false)
    }

    @IBAction func emailSwitched(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "email", sender: nil)
        } else {
            disable("email")
        }
    }

    @IBAction func smsSwitched(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "phone", sender: "sms")
        } else {
            disable("sms")
        }
    }

    @IBAction func phoneSwitched(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "phone", sender: "phone")
        } else {
            disable("phone")
        }
    }

    @IBAction func gauthSwithed(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "gauth", sender: nil)
        } else {
            disable("gauth")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SetPhoneViewController {
            if (sender as! String == "sms") {
                nextController.sms = true
            } else {
                nextController.phoneCall = true
            }
            nextController.onboarding = false
        }
    }

}
