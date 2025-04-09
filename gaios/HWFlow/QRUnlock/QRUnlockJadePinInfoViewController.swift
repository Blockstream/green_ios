import Foundation
import UIKit
import core
import gdk

class QRUnlockJadePinInfoViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var lblInfo1: UILabel!
    @IBOutlet weak var lblInfo2: UILabel!
    @IBOutlet weak var lblInfo3: UILabel!
    var testnet = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()
        loadNavigationBtns()
    }

    func setContent() {
        title = "id_setup_pin_via_qr".localized
        lblTitle.text = "id_qr_pin_unlock".localized
        lblHint.text = "id_allows_you_to_sign_transactions".localized
        btnNext.setTitle("id_start_qr_unlock".localized, for: .normal)
        lblInfo1.text = "id_setup_jade_and_backup_the".localized
        lblInfo2.text = "id_on_jade_select_qr__continue_".localized
        lblInfo3.text = "id_if_jade_is_already_set_up".localized
    }

    func setStyle() {
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txtCard)
        btnNext.setStyle(.primary)
        [lblInfo1, lblInfo2, lblInfo3].forEach {
            $0?.setStyle(.txt)
        }
    }

    func loadNavigationBtns() {
        let helpBtn = UIButton(type: .system)
        helpBtn.setImage(UIImage(named: "ic_help")?.maskWithColor(color: UIColor.gGreenMatrix()), for: .normal)
        helpBtn.addTarget(self, action: #selector(setupBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: helpBtn)
    }

    @objc func setupBtnTapped() {
        let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = hwFlow.instantiateViewController(withIdentifier: "SetupJadeViewController") as? SetupJadeViewController {
            present(vc, animated: true)
        }
    }

    @IBAction func btnNext(_ sender: Any) {
        let testnetAvailable = AppSettings.shared.testnet
        if testnetAvailable {
            selectNetwork()
        } else {
            next()
        }
    }

    func next() {
        let storyboard = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "QRUnlockJadeViewController") as? QRUnlockJadeViewController {
            vc.vm = QRUnlockJadeViewModel(scope: .oracle, testnet: testnet)
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: true)
        }
    }
}
extension QRUnlockJadePinInfoViewController: QRUnlockJadeViewControllerDelegate {
    func signerFlow() {
    }

    func signPsbt(_ psbt: String) {
    }

    func login(credentials: gdk.Credentials) {
        if let account = AccountsRepository.shared.current {
            AccountNavigator.goLogged(accountId: account.id)
        }
    }

    func abort() {
        DropAlert().error(message: "id_operation_failure".localized)
    }
}
extension QRUnlockJadePinInfoViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func selectNetwork() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "id_select_network".localized, type: .networkPrefs, items: NetworkPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch NetworkPrefs(rawValue: index) {
        case .mainnet:
            testnet = false
            next()
        case .testnet:
            testnet = true
            next()
        case .none:
            break
        }
    }
}
