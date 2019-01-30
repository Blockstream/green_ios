import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class SetGauthViewController: UIViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var secretLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var copyImage: UIImageView!
    var errorLabel: UIErrorLabel!
    var gauthData: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let dataTwoFactorConfig = try? getSession().getTwoFactorConfig() else { return }
        guard let twoFactorConfig = try? JSONDecoder().decode(TwoFactorConfig.self, from: JSONSerialization.data(withJSONObject: dataTwoFactorConfig!, options: [])) else { return }
        guard let secret = twoFactorConfig.gauthSecret() else {
            self.errorLabel.isHidden = false
            self.errorLabel.text =  NSLocalizedString("id_operation_failure", comment: "")
            return
        }
        self.secretLabel.text = secret
        self.gauthData = twoFactorConfig.gauth.data
        qrCodeImageView.image = QRImageGenerator.imageForTextWhite(text: gauthData!, frame: qrCodeImageView.frame)
        nextButton.setTitle(NSLocalizedString("id_get_code", comment: ""), for: .normal)
        title = NSLocalizedString("id_google_authenticator_qr_code", comment: "")
        subtitleLabel.text = NSLocalizedString("id_scan_the_qr_code_in_google", comment: "")
        warningLabel.text = NSLocalizedString("id_the_recovery_key_below_will_not", comment: "")
        secretLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action:  #selector(self.copyToClipboard)))
        copyImage.addGestureRecognizer(UITapGestureRecognizer(target: self, action:  #selector(self.copyToClipboard)))
        secretLabel.isUserInteractionEnabled = true
        copyImage.isUserInteractionEnabled = true
        errorLabel = UIErrorLabel(self.view)
    }

    @objc func copyToClipboard(_ sender: UIButton) {
        UIPasteboard.general.string = secretLabel.text
        Toast.show(NSLocalizedString("id_copy_to_clipboard", comment: ""), timeout: Toast.SHORT_DURATION)
    }

    @IBAction func nextButtonClicked(_ sender: Any) {
        guard let gauth = gauthData else { return }
        let config = TwoFactorConfigItem(enabled: true, confirmed: true, data: gauth)
        let bgq = DispatchQueue.global(qos: .background)
        firstly {
            self.errorLabel.isHidden = true
            self.startAnimating()
            return Guarantee()
        }.compactMap(on: bgq) {
            try getGAService().getSession().changeSettingsTwoFactor(method: TwoFactorType.gauth.rawValue, details: try JSONSerialization.jsonObject(with: JSONEncoder().encode(config), options: .allowFragments) as! [String : Any])
        }.then(on: bgq) { call in
            call.resolve(self)
        }.ensure {
            self.stopAnimating()
        }.done { _ in
            self.navigationController?.popViewController(animated: true)
        }.catch { error in
            self.errorLabel.isHidden = false
            if let twofaError = error as? TwoFactorCallError {
                switch twofaError {
                case .failure(let localizedDescription), .cancel(let localizedDescription):
                    self.errorLabel.text = localizedDescription
                }
            } else {
                self.errorLabel.text = error.localizedDescription
            }
        }
    }
}
