import UIKit
import core
import gdk
import greenaddress

class SetupNewViewController: UIViewController {
    enum State {
        case mobile
        case hardware
    }
    enum CtaType {
        case cta1
        case cta2
    }
    enum Action {
        case setupMobile
        case setupHardware
        case restore
        case buyJade
    }
    @IBOutlet weak var fadeView: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnCta1: UIButton!
    @IBOutlet weak var btnCta2: UIButton!
    @IBOutlet weak var animateView: UIView!
    @IBOutlet weak var lblSubtitle: UILabel!

    var state = State.mobile
    var viewModel = OnboardViewModel()

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
        lblTitle.text = ""
        lblSubtitle.text = "Create a new wallet to begin your bitcoin journey."
        btnCta1.setTitle("Setup Mobile Wallet".localized, for: .normal)
        btnCta2.setStyle(.underline(txt: "Restore from backup".localized, color: UIColor.gAccent()))
        //btnCta1.setTitle("Setup Hardware Wallet".localized, for: .normal)
        //btnCta2.setStyle(.underline(txt: "Don’t have one? Buy a Jade".localized, color: UIColor.gAccent()))
        let riveView = RiveModel.animationWallet.createRiveView()
        animateView.addSubview(riveView)
        riveView.frame = CGRect(x: 0.0, y: 0.0, width: animateView.frame.width, height: animateView.frame.height)
    }

    func setStyle() {
        btnCta1.setStyle(.primary)
        lblSubtitle.font = UIFont.systemFont(ofSize: 16.0, weight: .regular)
        lblSubtitle.textColor = UIColor.gGrayTxt()
    }

    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        settingsBtn.setImage(UIImage(named: "ic_nav_disclose"), for: .normal)
        settingsBtn.addTarget(self, action: #selector(settingsBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsBtn)
    }

    @objc func settingsBtnTapped() {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func updateState() {
        UIView.animate(withDuration: 0.2, delay: 0.0, options: UIView.AnimationOptions.curveEaseOut, animations: { [weak self] in
            self?.fadeView.alpha = 0.0
        }, completion: { [weak self] (_) -> Void  in
            self?.setContent()
            UIView.animate(withDuration: 0.2, delay: 0.0, options: UIView.AnimationOptions.curveEaseIn, animations: { [weak self] in
                self?.fadeView.alpha = 1.0
            }, completion: nil)
        })
    }

    func next() {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if OnboardViewModel.flowType == .add {
            Task { await self.create() }
        } else if OnboardViewModel.flowType == .restore {
            if let vc = storyboard.instantiateViewController(withIdentifier: "MnemonicViewController") as? MnemonicViewController {
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    func create() async {
        startLoader()
        let task = Task.detached { [weak self] in
            try await self?.viewModel.createWallet(pin: nil)
        }
        switch await task.result {
        case .success(let wm):
            stopLoader()
            if let account = wm?.account {
                AccountsRepository.shared.current = account
                AccountNavigator.goLogged(accountId: account.id, isFirstLoad: true)
            }
        case .failure(let err):
            stopLoader()
            if let err = err as? AuthenticationTypeHandler.AuthError {
                let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "OnBoardAppAccessViewController") as? OnBoardAppAccessViewController {
                    navigationController?.pushViewController(vc, animated: true)
                    return
                }
            }
            showError(err.description().localized)
        }
    }

    func tryNext(_ action: Action) {

        switch action {
        case .setupMobile:
            OnboardViewModel.flowType = .add
        case .setupHardware:
            let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "WelcomeJadeViewController") as? WelcomeJadeViewController {
                navigationController?.pushViewController(vc, animated: true)
                AnalyticsManager.shared.hwwWallet()
            }
            return
        case .restore:
            OnboardViewModel.flowType = .restore
        case .buyJade:
            SafeNavigationManager.shared.navigate( ExternalUrls.buyJadePlus )
            return
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

    @IBAction func btnCta1(_ sender: Any) {
        switch state {
        case .mobile:
            tryNext(.setupMobile)
        case .hardware:
            tryNext(.setupHardware)
        }
    }

    @IBAction func btnCta2(_ sender: Any) {
        switch state {
        case .mobile:
            tryNext(.restore)
        case .hardware:
            tryNext(.buyJade)
        }
    }
}

extension SetupNewViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch NetworkPrefs(rawValue: index) {
        case .mainnet:
            OnboardViewModel.chainType = .mainnet
            next()
        case .testnet:
            OnboardViewModel.chainType = .testnet
            next()
        case .none:
            break
        }
    }
}
