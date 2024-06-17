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
        title = "Set Pin via QR"
        lblTitle.text = "Set your PIN via QR on your Jade to get started".localized
        lblHint.text = "This allows you to sign transactions and validate addresses using Jade's camera".localized
        btnNext.setTitle("Start QR Unlock".localized, for: .normal)
        lblInfo1.text = "A fully air-gapped workflow, no USB or Bluetooth required"
        lblInfo2.text = "Keep your keys encrypted on Jade, easily accessible with PIN"
        lblInfo3.text = "Not vulnerable to brute-force attacks due to Jade’s unique security model"
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblHint.font = UIFont.systemFont(ofSize: 20.0, weight: .regular)
        lblHint.textColor = .gW60()
        btnNext.setStyle(.primary)
        [lblInfo1, lblInfo2, lblInfo3].forEach {
            $0?.setStyle(.txt)
        }
    }

    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        settingsBtn.tintColor = UIColor.gGreenMatrix()
        settingsBtn.setTitle("id_setup_guide".localized, for: .normal)
        settingsBtn.addTarget(self, action: #selector(setupBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsBtn)
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
            AccountNavigator.goLogged(account: account)
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
            vc.viewModel = DialogListViewModel(title: "Select Network", type: .networkPrefs, items: NetworkPrefs.getItems())
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
