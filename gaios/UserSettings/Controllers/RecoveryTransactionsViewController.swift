import UIKit
import PromiseKit
import gdk
import greenaddress

class RecoveryTransactionsViewController: UIViewController {

    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnMoreInfo: UIButton!
    @IBOutlet weak var bg1: UIView!
    @IBOutlet weak var bg2: UIView!
    @IBOutlet weak var lblTitle1: UILabel!
    @IBOutlet weak var lblTitle2: UILabel!
    @IBOutlet weak var actionSwitch: UISwitch!

    var session: SessionManager?
    let bgq = DispatchQueue.global(qos: .background)

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        update()
    }

    func setContent() {
        title = "id_recovery_transactions".localized
        lblTitle1.text = "id_recovery_transaction_emails".localized
        lblTitle2.text = "id_request_recovery_transactions".localized
        lblHint.text = "id_if_you_have_some_coins_on_the".localized
        btnMoreInfo.setTitle("id_more_info".localized, for: .normal)
    }

    func setStyle() {
        [bg1, bg2].forEach{ $0?.cornerRadius = 5.0 }
        [lblTitle1, lblTitle2].forEach{ $0?.setStyle(.titleCard)}
        lblHint.setStyle(.txtCard)
        btnMoreInfo.setStyle(.outlined)
    }

    func update() {
        if let notifications = session?.settings?.notifications {
            actionSwitch.isOn = notifications.emailOutgoing == true
        }
    }

    func enableRecoveryTransactions(_ enable: Bool) {
        guard let session = session, let settings = session.settings else { return }
        settings.notifications = SettingsNotifications(emailIncoming: enable,
                                                       emailOutgoing: enable)
        Guarantee()
            .then(on: bgq) { session.changeSettings(settings: settings) }
            .done { _ in self.update() }
            .catch { err in
                self.showError( err.localizedDescription )
            }
    }

    @IBAction func actionSwitchChange(_ sender: Any) {
        enableRecoveryTransactions(actionSwitch.isOn)
    }

    @IBAction func btnRequest(_ sender: Any) {
        self.showError("To be defined")
    }

    @IBAction func btnMoreInfo(_ sender: Any) {
        SafeNavigationManager.shared.navigate( ExternalUrls.helpRecoveryTransactions )
    }
}