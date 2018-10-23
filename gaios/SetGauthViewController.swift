import Foundation
import UIKit

class SetGauthViewController: UIViewController {

    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var secretLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    var secret: String? = ""
    var otp: String? = ""
    @IBOutlet weak var titleLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        secret = AccountStore.shared.getGauthSecret()
        otp = AccountStore.shared.getGauthOTP()
        if (secret == nil) {
            print("something went wrong gauth")
            return
        }
        qrCodeImageView.image = QRImageGenerator.imageForText(text: otp!, frame: qrCodeImageView.frame)
        secretLabel.text = secret
        nextButton.setTitle(NSLocalizedString("pnext", comment: ""), for: .normal)
        titleLabel.text = NSLocalizedString("pgoogle_authenticator_qrcode", comment: "")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func nextButtonClicked(_ sender: Any) {
        let factor = AccountStore.shared.enableGauthTwoFactor()
        do {
            let json = try factor?.getStatus()
            let status = json!["status"] as! String
            if (status == "call") {
                try factor?.call()
                let json_call = try factor?.getStatus()
                let status_call = json_call!["status"] as! String
                if(status_call == "resolve_code") {
                    self.performSegue(withIdentifier: "twoFactor", sender: factor)
                }
            } else if (status == "request_code") {
                let methods = json!["methods"] as! NSArray
                if(methods.count > 1) {
                    self.performSegue(withIdentifier: "twoFactorSelector", sender: factor)
                } else {
                    let method = methods[0] as! String
                    let req = try factor?.requestCode(method: method)
                    let status1 = try factor?.getStatus()
                    let parsed1 = status1!["status"] as! String
                    if(parsed1 == "resolve_code") {
                        self.performSegue(withIdentifier: "twoFactor", sender: factor)
                    }
                }
            }
        } catch {
            print("something went wrong")
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? VerifyTwoFactorViewController {
            nextController.onboarding = true
            nextController.twoFactor = sender as! TwoFactorCall
        }
        if let nextController = segue.destination as? TwoFactorSlectorViewController {
            nextController.twoFactor = sender as! TwoFactorCall
        }
    }
}
