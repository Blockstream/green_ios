import UIKit
import core
import gdk
import greenaddress

class GetStartedOnBoardViewController: UIViewController {

    enum ActionToButton {
        case getStarted
        case connect
    }

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnGetStarted: UIButton!
    @IBOutlet weak var btnConnectJade: UIButton!
    @IBOutlet weak var labelAgree: UILabel!

    var actionToButton: ActionToButton?

    let strIAgree = "id_by_using_the_blockstream_app".localized
    let strTerms = "id_terms__conditions".localized
    let strPrivacy = "id_privacy_policy".localized

    var acceptedTerms: Bool {
        get { UserDefaults.standard.bool(forKey: AppStorageConstants.acceptedTerms.rawValue) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppStorageConstants.acceptedTerms.rawValue) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        loadNavigationBtns()
    }

    @objc func back(sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    func setContent() {
        lblHint.text = "id_everything_you_need_to_take".localized
        btnGetStarted.setTitle("id_get_started".localized, for: .normal)
        btnConnectJade.setTitle("id_connect_jade".localized, for: .normal)
        lblTitle.attributedText = textWithLineSpacing(text: "id_simple__secure_selfcustody".localized, spacing: 0)
    }

    func textWithLineSpacing(text: String, spacing: CGFloat) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 0.85
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = spacing
        attributedString.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: text.count))
        return attributedString
    }

    func setStyle() {
        lblTitle.font = UIFont.systemFont(ofSize: 32.0, weight: .bold)
        lblTitle.textColor = .white
        lblTitle.textAlignment = .center
        lblHint.font = UIFont.systemFont(ofSize: 16.0, weight: .regular)
        lblHint.textColor = UIColor.gGrayTxt()
        lblHint.textAlignment = .center
        btnGetStarted.setStyle(.primary)

        let pStyle = NSMutableParagraphStyle()
        pStyle.lineSpacing = 2.0
        let gAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.gAccent(),
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let attrStr = NSMutableAttributedString(string: strIAgree)
        attrStr.addAttribute (
            NSAttributedString.Key.paragraphStyle,
            value: pStyle,
            range: NSRange(location: 0, length: attrStr.length))
        attrStr.setAttributes(gAttr, for: strTerms)
        attrStr.setAttributes(gAttr, for: strPrivacy)
        labelAgree.attributedText = attrStr
        labelAgree.isUserInteractionEnabled = true
        labelAgree.lineBreakMode = .byWordWrapping
        labelAgree.textAlignment = .center
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(onTap(_:)))
        tapGesture.numberOfTouchesRequired = 1
        labelAgree.addGestureRecognizer(tapGesture)
        btnGetStarted.setStyle(.primary)
        btnConnectJade.setStyle(.outlined)
    }

    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        settingsBtn.setImage(UIImage(named: "ic_nav_disclose"), for: .normal)
        settingsBtn.addTarget(self, action: #selector(settingsBtnTapped), for: .touchUpInside)
        let aboutBtn = UIButton(type: .system)
        aboutBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        aboutBtn.setImage(UIImage(named: "ic_tab_security"), for: .normal)
        aboutBtn.addTarget(self, action: #selector(aboutBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: settingsBtn), UIBarButtonItem(customView: aboutBtn)]
    }

    @objc func aboutBtnTapped() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAboutViewController") as? DialogAboutViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }

    @objc func onTap(_ gesture: UITapGestureRecognizer) {
        guard let text = labelAgree.text else { return }
        let rangeTerms = (text.lowercased() as NSString).range(of: strTerms.lowercased())
        let rangePrivacy = (text.lowercased() as NSString).range(of: strPrivacy.lowercased())
        if gesture.didTapAttributedTextInLabel(label: labelAgree, inRange: rangeTerms) {
            navigate(ExternalUrls.aboutTermsOfService)
        } else if gesture.didTapAttributedTextInLabel(label: labelAgree, inRange: rangePrivacy) {
            navigate(ExternalUrls.aboutPrivacyPolicy)
        }
    }

    @objc func settingsBtnTapped() {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func navigate(_ url: URL) {
        SafeNavigationManager.shared.navigate(url)
    }

    func tryNext(_ action: ActionToButton) {
        if AnalyticsManager.shared.consent == .notDetermined {
            actionToButton = action

            let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "DialogCountlyViewController") as? DialogCountlyViewController {
                vc.modalPresentationStyle = .overFullScreen
                vc.delegate = self
                self.present(vc, animated: false, completion: nil)
            }
            return
        }
        switch action {
        case .getStarted:
//            OnBoardManager.shared.flowType = .add
            let flow = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = flow.instantiateViewController(withIdentifier: "SetupNewViewController") as? SetupNewViewController {
                navigationController?.pushViewController(vc, animated: true)
            }
            return
        case .connect:
            let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "WelcomeJadeViewController") as? WelcomeJadeViewController {
                navigationController?.pushViewController(vc, animated: true)
                AnalyticsManager.shared.hwwWallet()
            }
            return
        }
    }

    @IBAction func btnGetStarted(_ sender: Any) {
        AnalyticsManager.shared.getStarted()
        tryNext(.getStarted)
    }

    @IBAction func btnConnect(_ sender: Any) {
        tryNext(.connect)
    }
}

extension GetStartedOnBoardViewController: DialogCountlyViewControllerDelegate {
    func didChangeConsent() {
        switch AnalyticsManager.shared.consent {
        case .notDetermined:
            break
        case .denied, .authorized:
            if let actionToButton = actionToButton {
                tryNext(actionToButton)
            }
        }
    }
}
extension GetStartedOnBoardViewController: DialogAboutViewControllerDelegate {
    func openContactUs() {
        presentContactUsViewController(request: ZendeskErrorRequest(shareLogs: true))
    }
}

//extension GetStartedOnBoardViewController: DialogListViewControllerDelegate {
//    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}
//
//    func didSelectIndex(_ index: Int, with type: DialogType) {
//        switch NetworkPrefs(rawValue: index) {
//        case .mainnet:
//            OnBoardManager.shared.chainType = .mainnet
//            next()
//        case .testnet:
//            OnBoardManager.shared.chainType = .testnet
//            next()
//        case .none:
//            break
//        }
//    }
//}
