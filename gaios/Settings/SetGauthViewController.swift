import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class SetGauthViewController: UIViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var secretLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    var secret: String? = ""
    var otp: String? = ""
    var errorLabel: UIErrorLabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        secret = AccountStore.shared.getGauthSecret()
        otp = AccountStore.shared.getGauthOTP()
        if (secret == nil) {
            self.errorLabel.isHidden = false
            self.errorLabel.text = "something went wrong gauth"
            return
        }
        qrCodeImageView.image = QRImageGenerator.imageForText(text: otp!, frame: qrCodeImageView.frame)
        secretLabel.text = secret
        nextButton.setTitle(NSLocalizedString("id_next", comment: ""), for: .normal)
        title = NSLocalizedString("id_google_authenticator_qr_code", comment: "")
        errorLabel = UIErrorLabel(self.view)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func nextButtonClicked(_ sender: Any) {

        let config = try! getSession().getTwoFactorConfig()
        let gauth = config!["gauth"] as! [String: Any]
        let gauthdata = gauth["data"] as! String
        let dict = ["enabled": true, "confirmed": true, "data": gauthdata] as [String : Any]

        let bgq = DispatchQueue.global(qos: .background)
        firstly {
            self.errorLabel.isHidden = true
            startAnimating(type: NVActivityIndicatorType.ballRotateChase)
            return Guarantee()
        }.then(on: bgq) {
            return Guarantee().compactMap(on: bgq) {
                try getSession().changeSettingsTwoFactor(method: "gauth", details: dict)
            }
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.ensure {
            self.stopAnimating()
        }.done { _ in
            self.navigationController?.popViewController(animated: true)
        }.catch { error in
            self.errorLabel.isHidden = false
            self.errorLabel.text = NSLocalizedString(error.localizedDescription, comment: "")
        }
    }
}
