import Foundation
import UIKit
import core
import gdk

class SetGauthViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var secretLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var btnCopy: UIButton!

    var session: SessionManager!
    private var gauthData: String?
    private var connected = true
    private var updateToken: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        lblTitle.text = "id_authenticator_qr_code".localized

        guard let session = session.session,
              let dataTwoFactorConfig = try? session.getTwoFactorConfig(),
              let twoFactorConfig = try? JSONDecoder().decode(TwoFactorConfig.self, from: JSONSerialization.data(withJSONObject: dataTwoFactorConfig, options: [])) else { return }
        gauthData = twoFactorConfig.gauth.data
        guard let secret = twoFactorConfig.gauthSecret() else {
            DropAlert().error(message: "id_operation_failure".localized)
            return
        }
        secretLabel.text = secret
        qrCodeImageView.image = QRImageGenerator.imageForTextWhite(text: gauthData!, frame: qrCodeImageView.frame)
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

        qrCodeImageView.isUserInteractionEnabled = true
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        qrCodeImageView.addGestureRecognizer(longPressRecognizer)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: EventType.Network.rawValue), object: nil, queue: .main, using: updateConnection)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let token = updateToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func copyToClipboard() {
        UIPasteboard.general.string = secretLabel.text
        DropAlert().info(message: "id_copy_to_clipboard".localized)
    }

    func updateConnection(_ notification: Notification) {
        if let data = notification.userInfo,
              let json = try? JSONSerialization.data(withJSONObject: data, options: []),
              let connection = try? JSONDecoder().decode(Connection.self, from: json) {
            self.connected = connection.connected
        }
    }

    func magnifyQR() {
        let stb = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = stb.instantiateViewController(withIdentifier: "MagnifyQRViewController") as? MagnifyQRViewController, let txt = gauthData {
            vc.qrTxt = txt
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
                try await session.changeSettingsTwoFactor(params)
                try await self.session.loadTwoFactorConfig()
                self.navigationController?.popViewController(animated: true)
            } catch {
                if let twofaError = error as? TwoFactorCallError {
                    switch twofaError {
                    case .failure(let localizedDescription), .cancel(let localizedDescription):
                        DropAlert().error(message: localizedDescription.localized)
                    }
                } else {
                    DropAlert().error(message: error.localizedDescription.localized)
                }
            }
            self.stopAnimating()
        }
    }

    @IBAction func btnCopy(_ sender: Any) {
        copyToClipboard()
    }
}
