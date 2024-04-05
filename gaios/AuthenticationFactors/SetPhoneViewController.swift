import Foundation
import UIKit
import core
import gdk

class SetPhoneViewController: KeyboardViewController {

    @IBOutlet weak var iconNetwork: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var countryCodeView: UIView!
    @IBOutlet weak var phoneView: UIView!

    @IBOutlet weak var countryCodeField: UITextField!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var nextButton: UIButton!

    @IBOutlet weak var btnCountryPicker: UIButton!

    var sms = false
    var phoneCall = false
    var network = NetworkSecurityCase.bitcoinMS
    var session: SessionManager { (WalletManager.current?.sessions[network.network])! }
    var isSmsBackup = false

    private var connected = true
    private var updateToken: NSObjectProtocol?

    @IBOutlet weak var lblAgree: UILabel!
    @IBOutlet weak var lblFrequency: UILabel!
    @IBOutlet weak var lblHelp: UILabel!
    
    var icon: UIImage {
        get {
            switch network {
            case .bitcoinMS:
                return UIImage(named: "ntw_btc")!
            case .liquidMS:
                return UIImage(named: "ntw_liquid")!
            case .testnetLiquidMS:
                return UIImage(named: "ntw_testnet_liquid")!
            default:
                return UIImage(named: "ntw_testnet")!
            }
        }
    }
    
    let strIAgree = "By continuing you agree to Blockstream's Terms of Service and Privacy Policy".localized
    let strTerms = "Terms of Service".localized
    let strPrivacy = "Privacy Policy".localized

    let strFrequency = "Message frequency varies according to the number of 2FA SMS requests you make.".localized
    
    let strHelp = "For help visit help.blockstream.com To unsubscribe turn off SMS 2FA from the app. Standard messages and data rates may apply.".localized
    let strBlockcom = "help.blockstream.com".localized
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setContent()
        setStyle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: EventType.Network.rawValue), object: nil, queue: .main, using: updateConnection)
        countryCodeField.addTarget(self, action: #selector(onTapCountry), for: UIControl.Event.touchDown)

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let token = updateToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func setContent() {
        
        iconNetwork.image = icon
        title = "Two-Factor Setup".localized
        lblTitle.text = "Multisig".localized
        lblHint.text = "id_insert_your_phone_number_to".localized
        countryCodeField.attributedPlaceholder = NSAttributedString(string: "id_country".localized, attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.6)])
        textField.attributedPlaceholder = NSAttributedString(string: "id_phone_number".localized.capitalized, attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.6)])

        nextButton.setTitle("Setup 2FA".localized, for: .normal)
        
        [lblAgree, lblFrequency, lblHelp].forEach{
            $0?.isHidden = !sms
        }
    }
    
    func setStyle() {
        
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtCard)
        nextButton.addTarget(self, action: #selector(click), for: .touchUpInside)
        nextButton.setStyle(.primaryDisabled)
        [countryCodeView, phoneView].forEach {
            $0.layer.cornerRadius = 5.0
        }
        
        let pStyle = NSMutableParagraphStyle()
        pStyle.lineSpacing = 7.0
        pStyle.alignment = .center
        
        let cAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.gW40(),
            .font: UIFont.systemFont(ofSize: 14.0, weight: .regular)
        ]
        let gAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.gGreenMatrix(),
            .font: UIFont.systemFont(ofSize: 14.0, weight: .bold)
        ]
        let attrStr = NSMutableAttributedString(string: strIAgree)
        attrStr.addAttribute (
            NSAttributedString.Key.paragraphStyle,
            value: pStyle,
            range: NSRange(location: 0, length: attrStr.length))
        attrStr.setAttributes(cAttr, for: strIAgree)
        attrStr.setAttributes(gAttr, for: strTerms)
        attrStr.setAttributes(gAttr, for: strPrivacy)
        lblAgree.attributedText = attrStr
        lblAgree.isUserInteractionEnabled = true
        lblAgree.lineBreakMode = .byWordWrapping
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(onTapLblAgree(_:)))
        tapGesture.numberOfTouchesRequired = 1
        lblAgree.addGestureRecognizer(tapGesture)

        let attrStr2 = NSMutableAttributedString(string: strFrequency)
        attrStr2.addAttribute (
            NSAttributedString.Key.paragraphStyle,
            value: pStyle,
            range: NSRange(location: 0, length: attrStr2.length))
        attrStr2.setAttributes(cAttr, for: strFrequency)
        lblFrequency.attributedText = attrStr2
        lblFrequency.lineBreakMode = .byWordWrapping
        
        let attrStr3 = NSMutableAttributedString(string: strHelp)
        attrStr3.addAttribute (
            NSAttributedString.Key.paragraphStyle,
            value: pStyle,
            range: NSRange(location: 0, length: attrStr3.length))
        attrStr3.setAttributes(cAttr, for: strHelp)
        attrStr3.setAttributes(gAttr, for: strBlockcom)
        lblHelp.attributedText = attrStr3
        lblHelp.isUserInteractionEnabled = true
        lblHelp.lineBreakMode = .byWordWrapping
        let tapGesture2 = UITapGestureRecognizer.init(target: self, action: #selector(onTapLblHelp(_:)))
        tapGesture.numberOfTouchesRequired = 1
        lblHelp.addGestureRecognizer(tapGesture2)
    }

    func updateConnection(_ notification: Notification) {
        if let data = notification.userInfo,
              let json = try? JSONSerialization.data(withJSONObject: data, options: []),
              let connection = try? JSONDecoder().decode(Connection.self, from: json) {
            self.connected = connection.connected
        }
    }

    @objc func onTapLblAgree(_ gesture: UITapGestureRecognizer) {
        guard let text = lblAgree.text else { return }
        let rangeTerms = (text.lowercased() as NSString).range(of: strTerms.lowercased())
        let rangePrivacy = (text.lowercased() as NSString).range(of: strPrivacy.lowercased())
        if gesture.didTapAttributedTextInLabel(label: lblAgree, inRange: rangeTerms) {
            navigate(ExternalUrls.aboutTermsOfService)
        } else if gesture.didTapAttributedTextInLabel(label: lblAgree, inRange: rangePrivacy) {
            navigate(ExternalUrls.aboutPrivacyPolicy)
        }
    }
    
    @objc func onTapLblHelp(_ gesture: UITapGestureRecognizer) {
        guard let text = lblHelp.text else { return }
        let rangeBlockcom = (text.lowercased() as NSString).range(of: strBlockcom.lowercased())
        if gesture.didTapAttributedTextInLabel(label: lblHelp, inRange: rangeBlockcom) {
            navigate(ExternalUrls.helpBlockstream)
        }
    }

    func navigate(_ url: URL) {
        SafeNavigationManager.shared.navigate(url)
    }
    
    @objc func onTapCountry(textField: UITextField) {
        print("country")
    }

    func didSelectCountry(_ country: Country) {
        countryCodeField.text = country.dialCodeString
    }

    @objc func click(_ sender: UIButton) {
        let method = self.sms == true ? TwoFactorType.sms : TwoFactorType.phone
        guard let countryCode = countryCodeField.text, let phone = textField.text else { return }
        if countryCode.isEmpty || phone.isEmpty {
            DropAlert().warning(message: NSLocalizedString("id_invalid_phone_number_format", comment: ""))
            return
        }
        view.endEditing(true)
        if method == .sms && ["001", "+1"].contains(countryCode) {
            showError("SMS delivery is unreliable in the US due to network operator policy changes. You can try to get your 2FA code via call instead.")
            return
        }
        self.startAnimating()
        Task {
            do {
                let config = TwoFactorConfigItem(enabled: true, confirmed: true, data: countryCode + phone, isSmsBackup: isSmsBackup)
                try await session.changeSettingsTwoFactor(method: method, config: config)
                _ = try await session.loadTwoFactorConfig()
                await MainActor.run {
                    if self.isSmsBackup {
                        DropAlert().success(message: "2FA Call is now enabled")
                    }
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                if let twofaError = error as? TwoFactorCallError {
                    switch twofaError {
                    case .failure(let localizedDescription), .cancel(let localizedDescription):
                        DropAlert().error(message: localizedDescription)
                    }
                } else {
                    DropAlert().error(message: error.localizedDescription)
                }
            }
            self.stopAnimating()
        }
    }

    @IBAction func editingChange(_ sender: Any) {
        guard let countryCode = countryCodeField.text, var phone = textField.text else { return }
                phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEnabled = !countryCode.isEmpty && !phone.isEmpty && phone.count > 7
        nextButton.setStyle(isEnabled ? .primary : .primaryDisabled)
    }

    @IBAction func btnCountryPicker(_ sender: Any) {
        
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "GreenPickerViewController") as? GreenPickerViewController {
            vc.vm = GreenPickerViewModel(title: "id_country".localized,
                                         item: nil,
                                         items: Country.pickerItems())
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
}

extension SetPhoneViewController: GreenPickerDelegate {

    func didSelectItem(_ idx: Int) {
        didSelectCountry(Country.all()[idx])
    }

    func didCancel() {}
}
