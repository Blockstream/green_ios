import Foundation
import UIKit

class EditTwoFactorViewController: UIViewController {

    @IBOutlet weak var emailSwitch: UISwitch!
    @IBOutlet weak var smsSwitch: UISwitch!
    @IBOutlet weak var phoneSwitch: UISwitch!
    @IBOutlet weak var gauth: UISwitch!


    override func viewDidLoad() {
        super.viewDidLoad()

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
        do {
            let json = try twoFactor?.getStatus()
            let status = json!["status"] as! String
            if(status == "request_code") {
                let methods = json!["methods"] as! NSArray
                if(methods.count > 1) {
                    self.performSegue(withIdentifier: "selectTwoFactor", sender: twoFactor)
                } else {
                    let method = methods[0] as! String
                    let req = try twoFactor?.requestCode(method: method)
                    let status1 = try twoFactor?.getStatus()
                    let parsed1 = status1!["status"] as! String
                    if(parsed1 == "resolve_code") {
                        self.performSegue(withIdentifier: "verifyCode", sender: twoFactor)
                    }
                }
            }
        } catch {
            print("couldn't get status ")
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
        } else if let nextController = segue.destination as? VerifyTwoFactorViewController {
            nextController.twoFactor = sender as! TwoFactorCall
            nextController.onboarding = false
        }
    }

}
