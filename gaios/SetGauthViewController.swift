import Foundation
import UIKit
import NVActivityIndicatorView

class SetGauthViewController: UIViewController, NVActivityIndicatorViewable, TwoFactorCallDelegate {

    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var secretLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    var secret: String? = ""
    var otp: String? = ""
    @IBOutlet weak var titleLabel: UILabel!
    var errorLabel: UIErrorLabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        secret = AccountStore.shared.getGauthSecret()
        otp = AccountStore.shared.getGauthOTP()
        if (secret == nil) {
            self.onError(nil, text: "something went wrong gauth")
            return
        }
        qrCodeImageView.image = QRImageGenerator.imageForText(text: otp!, frame: qrCodeImageView.frame)
        secretLabel.text = secret
        nextButton.setTitle(NSLocalizedString("id_next", comment: ""), for: .normal)
        titleLabel.text = NSLocalizedString("id_google_authenticator_qrcode", comment: "")
        errorLabel = UIErrorLabel(self.view)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        if !self.isAnimating {
            self.navigationController?.popViewController(animated: true)
        }
    }

    @IBAction func nextButtonClicked(_ sender: Any) {
        if self.isAnimating {
            return
        }
        errorLabel.isHidden = true
        self.startAnimating(CGSize(width: 30, height: 30),
                            type: NVActivityIndicatorType.ballRotateChase)
        DispatchQueue.global(qos: .background).async {
            wrap {
                try AccountStore.shared.enableGauthTwoFactor()!
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
        self.navigationController?.popViewController(animated: true)
    }

    func onError(_ sender: TwoFactorCallHelper?, text: String) {
        self.stopAnimating()
        errorLabel.isHidden = false
        errorLabel.text = NSLocalizedString(text, comment: "")
    }
}
