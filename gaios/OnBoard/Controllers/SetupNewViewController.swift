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
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var iconPlus: UIImageView!
    @IBOutlet weak var lblHint1: UILabel!
    @IBOutlet weak var lblHint2: UILabel!
    @IBOutlet weak var lblInfo1: UILabel!
    @IBOutlet weak var lblInfo2: UILabel!
    @IBOutlet weak var lblInfo3: UILabel!
    @IBOutlet weak var btnCta1: UIButton!
    @IBOutlet weak var btnCta2: UIButton!

    var state = State.mobile
    var viewModel = OnboardViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
    }

    @objc func back(sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    func setContent() {
        lblTitle.text = "Setup a New Wallet".localized
        segmentedControl .setTitle("Mobile".localized, forSegmentAt: 0)
        segmentedControl .setTitle("Hardware".localized, forSegmentAt: 1)
        switch state {
        case .mobile:
            lblHint1.text = "Security Level: 1".localized
            lblHint2.text = "Mobile".localized
            lblInfo1.text = "Ideal for small amounts of bitcoin".localized
            lblInfo2.text = "Convenient spending".localized
            lblInfo3.text = "Keys stored on mobile device".localized
            btnCta1.setTitle("Setup Mobile Wallet".localized, for: .normal)
            btnCta2.setStyle(.underline(txt: "Restore from backup".localized, color: UIColor.gAccent()))
            icon.isHidden = false
            iconPlus.isHidden = true
        case .hardware:
            lblHint1.text = "Security Level: 2".localized
            lblHint2.text = "Hardware".localized
            lblInfo1.text = "Ideal for long-term bitcoin storage".localized
            lblInfo2.text = "Mitigates common attacks risks".localized
            lblInfo3.text = "Keys stored on specialized device".localized
            btnCta1.setTitle("Setup Hardware Wallet".localized, for: .normal)
            btnCta2.setStyle(.underline(txt: "Don’t have one? Buy a Jade".localized, color: UIColor.gAccent()))
            icon.isHidden = true
            iconPlus.isHidden = false
        }
    }

    func setStyle() {
        lblTitle.setStyle(.subTitle)
        lblHint1.setStyle(.txtCard)
        lblHint2.setStyle(.title)
        lblHint2.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        lblInfo1.setStyle(.txt)
        lblInfo2.setStyle(.txt)
        lblInfo3.setStyle(.txt)
        btnCta1.setStyle(.primary)
        segmentedControl.setStyle(SegmentedStyle.defaultStyle)
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
        case .failure:
            stopLoader()
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "OnBoardAppAccessViewController") as? OnBoardAppAccessViewController {
                navigationController?.pushViewController(vc, animated: true)
            }
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

    @IBAction func segmentedControl(_ sender: Any) {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            state = .mobile
        case 1:
            state = .hardware
        default:
            break
        }
        updateState()
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
