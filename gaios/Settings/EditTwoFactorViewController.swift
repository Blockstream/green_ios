import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class EditTwoFactorViewController: UIViewController, NVActivityIndicatorViewable {

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
        let bgq = DispatchQueue.global(qos: .background)
        let dict = ["enabled": false] as [String : Any]
        firstly {
            self.errorLabel.isHidden = true
            startAnimating(type: NVActivityIndicatorType.ballRotateChase)
            return Guarantee()
        }.then(on: bgq) {
            return Guarantee().compactMap(on: bgq) {
                try getSession().changeSettingsTwoFactor(method: method, details: dict)
            }
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.ensure {
            self.stopAnimating()
            self.viewWillAppear(false)
        }.done {
        }.catch { error in
            self.errorLabel.isHidden = false
            self.errorLabel.text = NSLocalizedString(error.localizedDescription, comment: "")
        }
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
