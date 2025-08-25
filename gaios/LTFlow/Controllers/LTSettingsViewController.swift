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
    @IBOutlet weak var btnEmpty: UIButton!
    @IBOutlet weak var btnDisable: UIButton!
    @IBOutlet weak var btnSwaps: UIButton!
    @IBOutlet weak var btnSweep: UIButton!

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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    func setContent() {
        lblTitle.text = "id_lightning_network".localized
        lblSubtitle.text = "id_your_lightning_account_is_set".localized
        btnMnemonic.setTitle("id_show_recovery_phrase".localized, for: .normal)
        btnEmpty.setTitle("id_empty_lightning_account".localized, for: .normal)
        btnDisable.setTitle("id_disable_lightning".localized, for: .normal)
        btnSwaps.setTitle("id_rescan_swaps".localized, for: .normal)
        btnSweep.setTitle("id_sweep".localized, for: .normal)
        btnSweep.isHidden = viewModel.onchainBalanceSatoshi ?? 0 == 0
        btnEmpty.isHidden = viewModel.channelsBalance ?? 0 == 0
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblSubtitle.setStyle(.txtBigger)
        [btnEmpty, btnMnemonic, btnDisable, btnSwaps, btnSweep].forEach({ $0.setStyle(.outlined) })
    }

    func register() {
        ["LTSettingCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
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

    @IBAction func btnCloseChannel(_ sender: Any) {
        if let viewModel = viewModel.ltRecoverFundsViewModelSendAll() {
            pushLTRecoverFundsViewController(viewModel)
        }
    }

    @IBAction func btnSweep(_ sender: Any) {
        if let viewModel = viewModel.ltRecoverFundsViewModelSweep() {
            pushLTRecoverFundsViewController(viewModel)
        }
    }

    @IBAction func btnSwaps(_ sender: Any) {
        Task { [weak self] in
            await self?.rescanSwaps()
        }
    }

    @IBAction func btnDisable(_ sender: Any) {
        Task { [weak self] in
            await self?.disableLightning()
        }
    }

    func rescanSwaps() async {
        startLoader(message: "id_rescan_swaps_initiated".localized)
        let task = Task.detached { [weak self] in
            try await self?.viewModel.rescanSwaps()
        }
        switch await task.result {
        case .success:
            stopLoader()
            DropAlert().success(message: "Rescan Swaps completed".localized)
            tableView.reloadData()
        case .failure(let error):
            stopLoader()
            showError(error)
        }
    }
    func disableLightning() async {
        startLoader(message: "Disabling...")
        let task = Task.detached { [weak self] in
            await self?.viewModel.disableLightning()
        }
        switch await task.result {
        case .success:
            stopLoader()
            DropAlert().success(message: "Lightning disabled successfully")
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: EventType.newSubaccount.rawValue), object: nil, userInfo: nil)
            navigationController?.popViewController(animated: true)
        case .failure(let error):
            stopLoader()
            showError(error)
        }
    }

    func pushLTRecoverFundsViewController(_ model: LTRecoverFundsViewModel) {
        let ltFlow = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = ltFlow.instantiateViewController(withIdentifier: "LTRecoverFundsViewController") as? LTRecoverFundsViewController {
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
