import Foundation
import core
import UIKit
import gdk

enum LTSettingsNodeAction {
    case mnemonic
    case sendAll
    case disable
}

class LTSettingsViewController: UIViewController {

    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblSubtitle: UILabel!
    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var btnMnemonic: UIButton!
    @IBOutlet weak var btnDisable: UIButton!
    @IBOutlet weak var btnSweep: UIButton!
    @IBOutlet weak var btnNewAddr: UIButton!

    var viewModel: LTSettingsViewModel!
    private var nodeCellTypes: [LTSettingsCellType] { viewModel.cellTypes }

    private var hideBalance: Bool {
        return UserDefaults.standard.bool(forKey: AppStorageConstants.hideBalance.rawValue)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        register()
        setContent()
        setStyle()
        triggerReload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    func triggerReload() {
        Task { [weak self] in
            await self?.viewModel.updateNodeInfo()
            await MainActor.run {
                if self?.tableView?.refreshControl?.isRefreshing == true {
                    self?.tableView?.refreshControl?.endRefreshing()
                    self?.tableView.reloadData()
                }
            }
        }
    }

    func setContent() {
        lblTitle.text = "id_lightning_network".localized
        lblSubtitle.text = "id_your_lightning_account_is_set".localized
        btnMnemonic.setTitle("id_show_recovery_phrase".localized, for: .normal)
        btnDisable.setTitle("id_disable_lightning".localized, for: .normal)
        btnSweep.setTitle("Transfer Node Onchain Balance".localized, for: .normal)
        btnNewAddr.setTitle("id_generate_new_address".localized, for: .normal)
        btnSweep.isHidden = viewModel.onchainBalanceSatoshi ?? 0 == 0
        btnNewAddr.isHidden = !Bundle.main.dev
        btnDisable.isHidden = !Bundle.main.dev
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblSubtitle.setStyle(.txtBigger)
        [btnMnemonic, btnDisable, btnSweep, btnNewAddr].forEach({ $0.setStyle(.outlined) })
    }

    func register() {
        ["LTSettingCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
        tableView?.refreshControl = UIRefreshControl()
        tableView?.refreshControl!.tintColor = UIColor.white
        tableView?.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }

    @objc func pull(_ sender: UIRefreshControl? = nil) {
        triggerReload()
    }

    @IBAction func btnMnemonic(_ sender: Any) {
        pushShowMnemonicsViewController()
    }

    func pushShowMnemonicsViewController() {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ShowMnemonicsViewController") as? ShowMnemonicsViewController {
            vc.showBip85 = true
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func btnNewAddr(_ sender: Any) {
        Task { [weak self] in
            let address = await self?.viewModel.newAddress()
            self?.showAlert(
                title: "Onchain Address".localized,
                message: address ?? "") {
                    UIPasteboard.general.string = address
                }
        }
    }

    @IBAction func btnSweep(_ sender: Any) {
        if let viewModel = viewModel.ltRedeemViewModel() {
            pushLTRecoverFundsViewController(viewModel)
        }
    }

    @IBAction func btnDisable(_ sender: Any) {
        Task { [weak self] in
            await self?.disableLightning()
        }
    }

    func disableLightning() async {
        startLoader(message: "id_disabling".localized)
        let task = Task.detached { [weak self] in
            await self?.viewModel.disableLightning()
        }
        switch await task.result {
        case .success:
            stopLoader()
            DropAlert().success(message: "id_lightning_disabled_successfully".localized)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: EventType.newSubaccount.rawValue), object: nil, userInfo: nil)
            navigationController?.popViewController(animated: true)
        case .failure(let error):
            stopLoader()
            showError(error)
        }
    }

    func pushLTRecoverFundsViewController(_ model: LTRedeemViewModel) {
        let ltFlow = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = ltFlow.instantiateViewController(withIdentifier: "LTRedeemViewController") as? LTRedeemViewController {
            vc.viewModel = model
            vc.modalPresentationStyle = .overFullScreen
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension LTSettingsViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nodeCellTypes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: LTSettingCell.identifier) as? LTSettingCell {
            cell.selectionStyle = .none
            let cellType = nodeCellTypes[indexPath.row]
            let cellModel = viewModel.cellModelByType(cellType)
            cell.configure(model: cellModel)
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellType = nodeCellTypes[indexPath.row]
        switch cellType {
        case .id:
            UIPasteboard.general.string = viewModel.id
            DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 1.0)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        default:
            break
        }
    }
}
