import Foundation
import UIKit

class SetGauthViewController: UIViewController, TwoFactorCallDelegate{

    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var secretLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    var secret: String? = ""
    var otp: String? = ""
    var onboarding = true
    var twoFactorController: UIViewController? = nil

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
        nextButton.setTitle(NSLocalizedString("id_next", comment: ""), for: .normal)
        titleLabel.text = NSLocalizedString("id_google_authenticator_qrcode", comment: "")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func nextButtonClicked(_ sender: Any) {
        DispatchQueue.global(qos: .background).async {
            wrap {
                AccountStore.shared.enableGauthTwoFactor()
                }.done { (result: TwoFactorCall?) in
                    do {
                        let resultHelper = TwoFactorCallHelper(result!)
                        resultHelper.delegate = self
                        try resultHelper.resolve()
                    } catch {
                        print(error)
                    }
                } .catch { error in
                    print(error)
            }
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
        if(onboarding) {
            self.performSegue(withIdentifier: "mainMenu", sender: nil)
        } else {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }

    func onError(_ sender: TwoFactorCallHelper, text: String) {
        if (twoFactorController != nil) {
            twoFactorController?.dismiss(animated: false, completion: nil)
        }
    }

}
