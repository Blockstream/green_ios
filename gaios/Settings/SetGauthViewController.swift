import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class SetGauthViewController: UIViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var secretLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    var errorLabel: UIErrorLabel!
    var twoFactorConfig: TwoFactorConfig!

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let dataTwoFactorConfig = try? getSession().getTwoFactorConfig() else { return }
        guard let twoFactorConfig = try? JSONDecoder().decode(TwoFactorConfig.self, from: JSONSerialization.data(withJSONObject: dataTwoFactorConfig!, options: [])) else { return }
        guard let secret = twoFactorConfig.gauthSecret() else {
            self.errorLabel.isHidden = false
            self.errorLabel.text =  NSLocalizedString("id_operation_failure", comment: "")
            return
        }
        qrCodeImageView.image = QRImageGenerator.imageForText(text: twoFactorConfig.gauth.data, frame: qrCodeImageView.frame)
        secretLabel.text = secret
        nextButton.setTitle(NSLocalizedString("id_next", comment: ""), for: .normal)
        title = NSLocalizedString("id_google_authenticator_qr_code", comment: "")
        errorLabel = UIErrorLabel(self.view)
    }

    @IBAction func nextButtonClicked(_ sender: Any) {
        let config = TwoFactorConfigItem(enabled: true, confirmed: true, data: twoFactorConfig.gauth.data)
        let bgq = DispatchQueue.global(qos: .background)
        firstly {
            self.errorLabel.isHidden = true
            self.startAnimating()
            return Guarantee()
        }.compactMap(on: bgq) {
            try getGAService().getSession().changeSettingsTwoFactor(method: TwoFactorType.gauth.rawValue, details: try JSONSerialization.jsonObject(with: JSONEncoder().encode(config), options: .allowFragments) as! [String : Any])
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
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
