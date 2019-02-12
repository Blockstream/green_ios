import Foundation
import UIKit
import PromiseKit


class NotificationsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    private var items: Events { get { return getGAService().getEvents() } }
    private var twoFactorConfig: TwoFactorConfig?
    private var wallets = [WalletItem]()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = NSLocalizedString("id_notifications", comment: "")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.customTitaniumLight()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData(_:)), name: NSNotification.Name(rawValue: EventType.TwoFactorReset.rawValue), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData(_:)), name: NSNotification.Name(rawValue: EventType.Transaction.rawValue), object: nil)
        reloadData(nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let controller = self.tabBarController as? TabViewController else { return }
        controller.snackbar.isHidden = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.TwoFactorReset.rawValue), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Transaction.rawValue), object: nil)
        guard let controller = self.tabBarController as? TabViewController else { return }
        controller.snackbar.isHidden = true
    }

    @objc func reloadData(_ notification: NSNotification?) {
        let bgq = DispatchQueue.global(qos: .background)
        getSubaccounts().map(on: bgq) { wallets in
            self.wallets = wallets
            let dataTwoFactorConfig = try getSession().getTwoFactorConfig()
            self.twoFactorConfig = try? JSONDecoder().decode(TwoFactorConfig.self, from: JSONSerialization.data(withJSONObject: dataTwoFactorConfig!, options: []))
        }.done {
            self.tableView.reloadData()
        }.catch {_ in }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {let cell =
        tableView.dequeueReusableCell(withIdentifier: "cell",
                                      for: indexPath as IndexPath)
        let event = items[indexPath.row]
        let (title,description) = titleDescription(event)
        cell.textLabel!.text = title
        cell.detailTextLabel!.text = description
        cell.detailTextLabel!.numberOfLines = 4
        cell.selectionStyle = .none
        cell.setNeedsLayout()
        return cell;
    }

    func titleDescription(_ event: Event) -> (String, String) {
        switch event.type {
        case .Transaction:
            let title = NSLocalizedString("id_new_transaction", comment: "")
            guard let txEvent = event.get() as TransactionEvent? else { break }
            let txType = txEvent.type == "incoming" ? NSLocalizedString("id_incoming", comment: "") : NSLocalizedString("id_outgoing", comment: "")
            let txAmount = String.toBtc(satoshi: txEvent.satoshi)
            let walletsList = wallets.filter { txEvent.subAccounts.contains(Int($0.pointer)) }
            let txWalletName = wallets.isEmpty ? "" : walletsList[0].localizedName()
            let description = String(format: NSLocalizedString("id_new_s_transaction_of_s_in", comment: ""), txType, txAmount, txWalletName)
            return (title, description)
        case .TwoFactorReset:
            guard let twoFactorReset = getGAService().getTwoFactorReset() else { break }
            if !twoFactorReset.isResetActive { break }
            return (NSLocalizedString("id_twofactor_reset_in_progress", comment: ""), "")
        case .Settings:
            let title = NSLocalizedString("id_set_up_twofactor_authentication", comment: "")
            var description = ""
            guard let _ = twoFactorConfig else { break }
            if !twoFactorConfig!.anyEnabled {
                description = NSLocalizedString("id_your_wallet_is_not_yet_fully", comment: "")
            } else if twoFactorConfig!.enableMethods.count == 1 {
                description = NSLocalizedString("id_you_only_have_one_twofactor", comment: "")
            }
            return (title, description)
        default:
            break
        }
        return ("", "")
    }
}
