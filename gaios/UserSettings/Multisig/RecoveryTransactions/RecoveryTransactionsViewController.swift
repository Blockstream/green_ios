import UIKit
import core
import greenaddress

class RecoveryTransactionsViewController: UIViewController {

    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnMoreInfo: UIButton!
    @IBOutlet weak var item1: UIView!
    @IBOutlet weak var item2: UIView!
    @IBOutlet weak var item3: UIView!
    @IBOutlet weak var bg1: UIView!
    @IBOutlet weak var bg2: UIView!
    @IBOutlet weak var bg3: UIView!
    @IBOutlet weak var lblTitle1: UILabel!
    @IBOutlet weak var lblTitle2: UILabel!
    @IBOutlet weak var lblTitle3: UILabel!
    @IBOutlet weak var actionSwitch: UISwitch!

    private var viewModel: RecoveryTransactionsViewModel
    weak var coordinator: SettingsCoordinator?

    init?(coder: NSCoder, viewModel: RecoveryTransactionsViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
    }

    func setContent() {
        title = "id_recovery_transactions".localized
        lblTitle1.text = "id_recovery_transaction_emails".localized
        lblTitle2.text = "id_request_recovery_transactions".localized
        lblTitle3.text = "id_set_an_email_for_recovery".localized
        lblHint.text = "id_if_you_have_some_coins_on_the".localized
        btnMoreInfo.setTitle("id_more_info".localized, for: .normal)
    }

    func setStyle() {
        [bg1, bg2, bg3].forEach { $0?.cornerRadius = 5.0 }
        [lblTitle1, lblTitle2, lblTitle3].forEach { $0?.setStyle(.titleCard)}
        lblHint.setStyle(.txtCard)
        btnMoreInfo.setStyle(.outlined)
    }

    @MainActor
    func update() {
        emailIsSet(false)
        if let twoFactorEmail = viewModel.getTwoFactorItemEmail {
            if let maskedData = twoFactorEmail.maskedData, maskedData.count > 1, twoFactorEmail.confirmed == true {
                self.emailIsSet(true)
            } else {
                self.emailIsSet(false)
            }
        }
        if let notifications = viewModel.backend?.settings?.notifications {
            actionSwitch.isOn = notifications.emailIncoming == true
        }
    }

    func emailIsSet(_ flag: Bool) {
        [item1, item2].forEach {
            $0?.isHidden = !flag
        }
        item3.isHidden = flag
    }

    func enableRecoveryTransactions(_ enable: Bool) {
        Task { [weak self] in
            do {
                _ = try await self?.viewModel.enableRecoveryTransactions(enable: enable)
                self?.update()
            } catch {
                self?.showError(error)
            }
        }
    }

    @IBAction func actionSwitchChange(_ sender: Any) {
        enableRecoveryTransactions(actionSwitch.isOn)
    }

    @IBAction func btnRequest(_ sender: Any) {
        self.startAnimating()
        Task {
            do {
                try await viewModel.sendNlocktimes()
                await MainActor.run {
                    DropAlert().success(message: "id_recovery_transaction_request".localized)
                }
            } catch {
                self.showError(error.description().localized)
            }
            self.stopAnimating()
        }
    }

    @IBAction func btnSetEmail(_ sender: Any) {
        guard let coordinator else { return }
        coordinator.navigate(to: .setEmailViewController(
            coordinator.set2FAViewModel(networkId: viewModel.networkId, method: .email, isSetRecovery: true)
        ))
    }

    @IBAction func btnMoreInfo(_ sender: Any) {
        SafeNavigationManager.shared.navigate( ExternalUrls.helpRecoveryTransactions )
    }
}
