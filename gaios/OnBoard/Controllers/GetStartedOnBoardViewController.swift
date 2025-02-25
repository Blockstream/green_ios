import UIKit
import core

class GetStartedOnBoardViewController: UIViewController {

    enum ActionToButton {
        case getStarted
    }

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnCheckTerms: CheckButton!
    @IBOutlet weak var btnGetStarted: UIButton!
    @IBOutlet weak var btnAppSettings: UIButton!
    @IBOutlet weak var labelAgree: UILabel!

    var actionToButton: ActionToButton?

    let mash = UIImageView(image: UIImage(named: "il_mash")!)

    let strIAgree = "id_i_agree_to_the_terms_of_service".localized
    let strTerms = "id_terms_of_service".localized
    let strPrivacy = "id_privacy_policy".localized

    var acceptedTerms: Bool {
        get { UserDefaults.standard.bool(forKey: AppStorageConstants.acceptedTerms.rawValue) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppStorageConstants.acceptedTerms.rawValue) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mash.alpha = 0.6
        view.insertSubview(mash, at: 0)
        mash.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mash.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            mash.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            mash.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
            mash.heightAnchor.constraint(equalToConstant: view.frame.height / 1.8)
        ])

        setContent()
        setStyle()
        updateUI()
    }

    @objc func back(sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    func setContent() {
        lblTitle.text = "id_simple__secure_selfcustody".localized
        lblHint.text = "id_everything_you_need_to_take".localized
        btnGetStarted.setTitle("id_get_started".localized, for: .normal)
        btnAppSettings.setTitle("id_app_settings".localized, for: .normal)
    }

    func setStyle() {
        lblTitle.font = UIFont.systemFont(ofSize: 30.0, weight: .bold)
        lblTitle.textColor = .white
        lblHint.font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
        lblHint.textColor = .white.withAlphaComponent(0.6)
        btnGetStarted.setStyle(.primary)
        btnAppSettings.setStyle(.inline)
        btnAppSettings.setTitleColor(.white, for: .normal)

        let pStyle = NSMutableParagraphStyle()
        pStyle.lineSpacing = 7.0
        let gAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.gGreenMatrix(),
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
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(onTap(_:)))
        tapGesture.numberOfTouchesRequired = 1
        labelAgree.addGestureRecognizer(tapGesture)
    }

    func updateUI() {
        btnCheckTerms.isSelected = acceptedTerms
        btnGetStarted.isEnabled = acceptedTerms

        if acceptedTerms {
            btnGetStarted.setStyle(.primary)
        } else {
            btnGetStarted.setStyle(.primaryDisabled)
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

    func navigate(_ url: URL) {
        SafeNavigationManager.shared.navigate(url)
    }

    func onNext(_ action: ActionToButton) {

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
            let onBoardFlow = UIStoryboard(name: "OnBoard", bundle: nil)
            let vc = onBoardFlow.instantiateViewController(withIdentifier: "HowToSecureViewController")
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func btnCheckTerms(_ sender: Any) {
        acceptedTerms = btnCheckTerms.isSelected
        updateUI()
    }

    @IBAction func btnGetStarted(_ sender: Any) {
        onNext(.getStarted)
    }

    @IBAction func btnSettings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension GetStartedOnBoardViewController: DialogCountlyViewControllerDelegate {
    func didChangeConsent() {
        switch AnalyticsManager.shared.consent {
        case .notDetermined:
            break
        case .denied, .authorized:
            if let actionToButton = actionToButton {
                onNext(actionToButton)
            }
        }
    }
}
