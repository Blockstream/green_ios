import UIKit
import core

enum ActionOnButton {
    case new
    case restore
}

class StartOnBoardViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var btnNewWallet: UIButton!
    @IBOutlet weak var btnRestoreWallet: UIButton!

    static var flowType: OnBoardingFlowType = .add
    static var chainType: OnBoardingChainType = .mainnet

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        updateUI()

        AnalyticsManager.shared.recordView(.onBoardIntro)
    }

    @objc func back(sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    func setContent() {

        lblTitle.text = "id_take_control_your_keys_your".localized
        lblHint.text = "id_your_keys_secure_your_coins_on".localized
        btnNewWallet.setTitle("id_new_wallet".localized, for: .normal)
        btnRestoreWallet.setTitle("id_restore_wallet".localized, for: .normal)
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblHint.setStyle(.txtCard)
    }

    func updateUI() {
        btnNewWallet.setStyle(.primary)
        btnRestoreWallet.setStyle(.outlinedWhite)
    }

    func onNext(_ action: ActionOnButton) {

        switch action {
        case .new:
            OnboardViewModel.flowType = .add
        case .restore:
            OnboardViewModel.flowType = .restore
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

    func next() {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)

        switch OnboardViewModel.flowType {
        case .add:
            if let vc = storyboard.instantiateViewController(withIdentifier: "SetPinViewController") as? SetPinViewController {
                vc.pinFlow = OnboardViewModel.flowType == .add ? .create : .restore
                vc.viewModel = OnboardViewModel()
                navigationController?.pushViewController(vc, animated: true)
            }
        case .restore:
            if let vc = storyboard.instantiateViewController(withIdentifier: "MnemonicViewController") as? MnemonicViewController {
                navigationController?.pushViewController(vc, animated: true)
            }
        case .watchonly:
            break
        }
    }

    @IBAction func btnNewWallet(_ sender: Any) {
        AnalyticsManager.shared.newWallet()
        onNext(.new)
    }

    @IBAction func btnRestoreWallet(_ sender: Any) {
        AnalyticsManager.shared.restoreWallet()
        onNext(.restore)
    }
}

extension StartOnBoardViewController: DialogListViewControllerDelegate {
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
