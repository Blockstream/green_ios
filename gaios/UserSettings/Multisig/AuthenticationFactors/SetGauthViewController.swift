import Foundation
import UIKit
import core

class SetGauthViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var qrCodeView: QRCodeView!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var secretLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var btnCopy: UIButton!

    private var viewModel: Set2FAViewModel
    weak var coordinator: SettingsCoordinator?
    private var gauthData: String?

    init?(coder: NSCoder, viewModel: Set2FAViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        lblTitle.text = "id_authenticator_qr_code".localized
        gauthData = viewModel.backend?.twoFactorConfig?.gauth.data
        guard let secret = viewModel.backend?.twoFactorConfig?.gauthSecret() else {
            DropAlert().error(message: "id_operation_failure".localized)
            return
        }
        secretLabel.text = secret
        qrCodeView.configure(frames: [gauthData ?? ""])
        nextButton.setTitle("id_get_code".localized, for: .normal)
        subtitleLabel.text = "id_scan_the_qr_code_with_an".localized
        warningLabel.text = "id_the_recovery_key_below_will_not".localized
        warningLabel.setStyle(.err)
        nextButton.addTarget(self, action: #selector(click), for: .touchUpInside)
        nextButton.setStyle(.primary)
        lblTitle.setStyle(.subTitle24)
        subtitleLabel.setStyle(.txtCard)
        btnCopy.setTitle("id_copy".localized, for: .normal)
        btnCopy.cornerRadius = 3.0

        qrCodeView.isUserInteractionEnabled = true
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        qrCodeView.addGestureRecognizer(longPressRecognizer)
    }

    func copyToClipboard() {
        UIPasteboard.general.string = secretLabel.text
        DropAlert().info(message: "id_copy_to_clipboard".localized)
    }

    func magnifyQR() {
        if let txt = gauthData {
            let storyboard = UIStoryboard(name: "Qrcode", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "MagnifyQRViewController") { coder in
                MagnifyQRViewController(coder: coder, configuration: MagnifyQRConfiguration(qrTxt: txt))
            }
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    @objc func longPressed(sender: UILongPressGestureRecognizer) {

        if sender.state == UIGestureRecognizer.State.began {
            magnifyQR()
        }
    }

    @objc func click(_ sender: UIButton) {
        guard let gauth = gauthData else { return }
        self.startAnimating()
        Task {
            do {
                let config = TwoFactorConfigItem(enabled: true, confirmed: true, data: gauth)
                let params = ChangeSettingsTwoFactorParams(method: .gauth, config: config)
                try await viewModel.changeSettingsTwoFactor(params)
                self.stopAnimating()
                if let coordinator {
                    coordinator.pop()
                } else {
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                self.stopAnimating()
                DropAlert().error(message: error.description().localized)
            }
        }
    }

    @IBAction func btnCopy(_ sender: Any) {
        copyToClipboard()
    }
}
