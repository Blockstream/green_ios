import UIKit
import core
import gdk
import greenaddress

class GetStartedOnBoardViewController: UIViewController {

    enum ActionToButton {
        case create
        case connect
        case restore
    }

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnGetStarted: UIButton!

    @IBOutlet weak var btnCreate: UIButton!
    @IBOutlet weak var btnConnectJade: UIButton!
    @IBOutlet weak var btnRestore: UIButton!

    @IBOutlet weak var btnAppSettings: UIButton!
    @IBOutlet weak var labelAgree: UILabel!

    var actionToButton: ActionToButton?

    let strIAgree = "By using Blockstream Green, you agree to the Terms & Conditions and Privacy Policy.".localized
    let strTerms = "Terms & Conditions".localized
    let strPrivacy = "Privacy Policy".localized

    var acceptedTerms: Bool {
        get { UserDefaults.standard.bool(forKey: AppStorageConstants.acceptedTerms.rawValue) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppStorageConstants.acceptedTerms.rawValue) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        btnGetStarted.isHidden = true
        setContent()
        setStyle()
    }

    @objc func back(sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    func setContent() {
        lblTitle.text = "id_simple__secure_selfcustody".localized
        lblHint.text = "id_everything_you_need_to_take".localized
        btnGetStarted.setTitle("id_get_started".localized, for: .normal)
        btnAppSettings.setTitle("id_app_settings".localized, for: .normal)

        btnCreate.setTitle("Create a new Wallet".localized, for: .normal)
        btnConnectJade.setTitle("Connect Jade".localized, for: .normal)
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
        labelAgree.textAlignment = .center
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(onTap(_:)))
        tapGesture.numberOfTouchesRequired = 1
        labelAgree.addGestureRecognizer(tapGesture)
        btnCreate.setStyle(.primary)
        btnConnectJade.setStyle(.outlined)
        btnRestore.setStyle(.underline(txt: "Restore Existing Wallet".localized, color: UIColor.gGreenMatrix()))
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

    func next() {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)

        switch OnBoardManager.shared.flowType {
        case .add:
            Task { await self.create() }
//            if let vc = storyboard.instantiateViewController(withIdentifier: "OnBoardAppAccessViewController") as? OnBoardAppAccessViewController {
//                navigationController?.pushViewController(vc, animated: true)
//            }
        case .restore:
            if let vc = storyboard.instantiateViewController(withIdentifier: "MnemonicViewController") as? MnemonicViewController {
                navigationController?.pushViewController(vc, animated: true)
            }
        case .watchonly:
            break
        }
    }

    func createWallet() async throws -> WalletManager {
        let account = try await createAccount()
        _ = try await createCredentials(account: account)
        //let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoBioCredentials,  for: account.keychain)
        let pinData = try AuthenticationTypeHandler.getPinData(method: .AuthKeyBiometric, for: account.keychain)
        let credentials = Credentials(mnemonic: pinData.plaintextBiometric, pinData: pinData)
        let wallet = WalletsRepository.shared.getOrAdd(for: account)
        try await wallet.create(credentials)
        return wallet
    }

    func createAccount() async throws -> Account {
        let testnet = OnBoardManager.shared.chainType == .testnet ? true : false
        let name = AccountsRepository.shared.getUniqueAccountName(testnet: testnet)
        let mainNetwork: NetworkSecurityCase = testnet ? .testnetSS : .bitcoinSS
        return Account(name: name, network: mainNetwork)
    }

    func createCredentials(account: Account) async throws -> Credentials {
        let mnemonic = try generateMnemonic12()
        let credentials = Credentials(mnemonic: mnemonic)
        //try? AuthenticationTypeHandler.setCredentials(method: .AuthKeyWoBioCredentials, credentials: credentials, for: account.keychain)
        let PinData = PinData(encryptedData: "", pinIdentifier: UUID().uuidString, salt: "", encryptedBiometric: nil, plaintextBiometric: nil)
        try? AuthenticationTypeHandler.setPinData(method: .AuthKeyBiometric, pinData: PinData, extraData: mnemonic, for: account.keychain)
        return credentials
    }

    func create() async {
        startLoader()
        let task = Task.detached { [weak self] in
            try await self?.createWallet()
        }
        switch await task.result {
        case .success(_):
            stopLoader()
            let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "Container") as? ContainerViewController {
                vc.walletModel = WalletModel()
                vc.walletModel?.isFirstLoad = true
                let appDelegate = UIApplication.shared.delegate
                appDelegate?.window??.rootViewController = vc
            }
        case .failure(_):
            stopLoader()
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "OnBoardAppAccessViewController") as? OnBoardAppAccessViewController {
                navigationController?.pushViewController(vc, animated: true)
            }
        }
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
        case .create:
            OnBoardManager.shared.flowType = .add
        case .connect:
            let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "WelcomeJadeViewController") as? WelcomeJadeViewController {
                navigationController?.pushViewController(vc, animated: true)
                AnalyticsManager.shared.hwwWallet()
            }
            return
        case .restore:
            OnBoardManager.shared.flowType = .restore
        }
        let testnetAvailable = AppSettings.shared.testnet
        if testnetAvailable {
            selectNetwork()
        } else {
            next()
        }
    }

    func selectNetwork() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "id_select_network".localized, type: .networkPrefs, items: NetworkPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnGetStarted(_ sender: Any) {
        // onNext(.getStarted)
    }

    @IBAction func btnCreate(_ sender: Any) {
        tryNext(.create)
    }

    @IBAction func btnConnect(_ sender: Any) {
        tryNext(.connect)
    }

    @IBAction func btnRestore(_ sender: Any) {
        tryNext(.restore)
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
                tryNext(actionToButton)
            }
        }
    }
}
extension GetStartedOnBoardViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch NetworkPrefs(rawValue: index) {
        case .mainnet:
            OnBoardManager.shared.chainType = .mainnet
            next()
        case .testnet:
            OnBoardManager.shared.chainType = .testnet
            next()
        case .none:
            break
        }
    }
}
