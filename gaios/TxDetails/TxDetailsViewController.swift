import UIKit
import gdk

enum TxDetailsSection: Int, CaseIterable {
    case status = 0
    case amount = 1
    case info = 2
    case actions = 3
}

enum TableDividerStyle {
    case header
    case footer
}

protocol TxDetailsViewControllerDelegate: AnyObject {
    func onMemoEdit()
}

class TxDetailsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    weak var delegate: TxDetailsViewControllerDelegate?

    var vm: TxDetailsViewModel!

    var isWatchonly: Bool {
        WalletManager.current?.account.isWatchonly ?? false
    }
    var isSinglesig: Bool {
        vm.transaction.subaccountItem?.isSinglesig ?? true
    }

    var viewInExplorerPreference: Bool {
        get {
            return UserDefaults.standard.bool(forKey: vm.wallet.gdkNetwork.chain + "_view_in_explorer")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: vm.wallet.gdkNetwork.chain + "_view_in_explorer")
        }
    }

    private var transactionToken: NSObjectProtocol?
    private var blockToken: NSObjectProtocol?
    private var cantBumpFees: Bool {
        return vm.wallet.session?.isResetActive ?? false ||
        !vm.transaction.canRBF || isWatchonly
    }

    var headerH: CGFloat = 44.0

    override func viewDidLoad() {
        super.viewDidLoad()

        register()
        setContent()
        setStyle()
        
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.tintColor = UIColor.white
        tableView.refreshControl!.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
        navBarSetup()

        AnalyticsManager.shared.recordView(.transactionDetails, sgmt: AnalyticsManager.shared.sessSgmt(AccountsRepository.shared.current))

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        transactionToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: EventType.Transaction.rawValue), object: nil, queue: .main, using: refreshTransaction)
        blockToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: EventType.Block.rawValue), object: nil, queue: .main, using: refreshTransaction)
        tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let token = transactionToken {
            NotificationCenter.default.removeObserver(token)
            transactionToken = nil
        }
        if let token = blockToken {
            NotificationCenter.default.removeObserver(token)
            blockToken = nil
        }
    }

    func setContent() {
//        lblTitle.text = "id_bitcoin_denomination".localized
    }

    func setStyle() {
//        cardView.layer.cornerRadius = 20
//        cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
//        handle.cornerRadius = 1.5
//        lblTitle.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
    }

    func register() {
        vm.cells.forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    func navBarSetup() {
        title = "id_transaction_details".localized
//        let shareBtn = UIButton(type: .system)
//        shareBtn.setImage(UIImage(named: "ic_export"), for: .normal)
//        shareBtn.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
//        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: shareBtn)
    }

    @objc func handleRefresh(_ sender: UIRefreshControl? = nil) {
        tableView.reloadData { [weak self] in
            self?.tableView.refreshControl?.endRefreshing()
        }
    }

    func editNote() {
        if isWatchonly && !isSinglesig { return }
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogEditViewController") as? DialogEditViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.prefill = vm.transaction.memo ?? ""
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }

    func share() {

        AnalyticsManager.shared.shareTransaction(account: AccountsRepository.shared.current, isShare: true)
        // We have more options in liquid for confidential txs
        if vm.transaction.isLiquid {
            let storyboard = UIStoryboard(name: "Shared", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "DialogShareTxOptionViewController") as? DialogShareTxOptionViewController {
                vc.modalPresentationStyle = .overFullScreen
                vc.delegate = self
                present(vc, animated: false, completion: nil)
            }
        } else {
            if let url = urlForTx() {
                let tx: [Any] = [url]
                let shareVC = UIActivityViewController(activityItems: tx, applicationActivities: nil)
                //shareVC.popoverPresentationController?.sourceView = sender
                self.present(shareVC, animated: true, completion: nil)
            }
        }
    }

    func urlForTx() -> URL? {
        return URL(string: (vm.wallet.gdkNetwork.txExplorerUrl ?? "") + (vm.transaction.hash ?? ""))
    }

    func urlForTxUnblinded() -> URL? {
        return URL(string: (vm.wallet.gdkNetwork.txExplorerUrl ?? "") + (vm.transaction.hash ?? "") + vm.transaction.blindingUrlString())
    }

    func blidingDataString() -> String? {
        let blinding = vm.transaction.blindingData()
        let jsonData = try? JSONEncoder().encode(blinding)
        let jsonString = String(data: jsonData ?? Data(), encoding: .utf8)
        return jsonString
    }

    func openShare(_ option: TxShareOption) {
        switch option {
        case .confidential:
            if let url = urlForTx() {
                let shareVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                present(shareVC, animated: true, completion: nil)
            }
        case .nonConfidential:
            if let url = urlForTxUnblinded() {
                let shareVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                present(shareVC, animated: true, completion: nil)
            }
        case .unblindingData:
            if let str = blidingDataString() {
                let shareVC = UIActivityViewController(activityItems: [str], applicationActivities: nil)
                present(shareVC, animated: true, completion: nil)
            }
        }
    }

    func openExplorer(_ option: ExplorerOption) {
        var exUrl: URL?
        switch option {
        case .confidential:
            exUrl = urlForTx()
        case .nonConfidential:
            exUrl = urlForTxUnblinded()
        }
        guard let url = exUrl else { return }
        let host = url.host!.starts(with: "www.") ? String(url.host!.prefix(5)) : url.host!
        if viewInExplorerPreference {
            SafeNavigationManager.shared.navigate(url)
            return
        }
        let message = String(format: NSLocalizedString("id_are_you_sure_you_want_to_view", comment: ""), host)
        let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { (_: UIAlertAction) in
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_only_this_time", comment: ""), style: .default) { (_: UIAlertAction) in
            SafeNavigationManager.shared.navigate(url)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_always", comment: ""), style: .default) { (_: UIAlertAction) in
            self.viewInExplorerPreference = true
            SafeNavigationManager.shared.navigate(url)
        })
        present(alert, animated: true, completion: nil)
    }

    func explorerAction() {
        if vm.transaction.isLiquid {
            let storyboard = UIStoryboard(name: "Shared", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "DialogExplorerOptionsViewController") as? DialogExplorerOptionsViewController {
                vc.modalPresentationStyle = .overFullScreen
                vc.delegate = self
                present(vc, animated: false, completion: nil)
            }
        } else {
            openExplorer(.confidential)
        }
    }

    func moreDetails() {
        let storyboard = UIStoryboard(name: "TxDetails", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TxDetailsMoreInfoViewController") as? TxDetailsMoreInfoViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.vm = TxDetailsMoreInfoViewModel(transaction: vm.transaction)
            present(vc, animated: false, completion: nil)
        }
    }

    func refreshTransaction(_ notification: Notification) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    func copyToClipboard(_ value: String) {

        AnalyticsManager.shared.shareTransaction(account: AccountsRepository.shared.current, isShare: false)

        UIPasteboard.general.string = value
        DropAlert().info(message: NSLocalizedString("id_copied_to_clipboard", comment: ""), delay: 1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func increaseFeeTapped() {
        if self.cantBumpFees { return }
        guard let session = vm.wallet.session else { return }
        Task {
            let unspentOutputs = try? await session.getUnspentOutputs(subaccount: vm.wallet.pointer, numConfs: 1)
            let feeRates = try? await session.getFeeEstimates()
            let feeRate = feeRates?.first ?? session.gdkNetwork.defaultFee
            let details = ["previous_transaction": vm.transaction.details,
                           "fee_rate": vm.transaction.feeRate + feeRate,
                           "subaccount": vm.wallet.pointer,
                           "utxos": unspentOutputs as Any]
            let tx = try? await session.createTransaction(tx: Transaction(details))
            let storyboard = UIStoryboard(name: "Send", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "SendViewController") as? SendViewController {
                vc.viewModel = SendViewModel(account: vm.wallet,
                                             inputType: .bumpFee,
                                             transaction: tx,
                                             input: nil,
                                             addressInputType: nil)
                vc.fixedWallet = true
                vc.fixedAsset = true
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    func didSelectInfoAt(_ index: Int) {
        let m: TxDetailsInfoCellModel = vm.txDetailsInfoCellModels[index]
        let txInfo = m.type
        switch txInfo {
        case .address, .txId:
            UIPasteboard.general.string = m.hint
            DropAlert().info(message: m.title, delay: 1.0)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        default:
            break
        }
    }
    
    func didSelectAmountAt(_ index: Int) {
        if !vm.transaction.isLiquid { return }
        Task {
            let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "DialogDetailViewController") as? DialogDetailViewController {
                let assetAmount = vm.assetAmountList.amounts[index]
                vc.tag = assetAmount.0
                vc.asset = (vm.assetAmountList.assets[vc.tag])!
                vc.satoshi = assetAmount.1
                vc.modalPresentationStyle = .overFullScreen
                present(vc, animated: false, completion: nil)
            }
        }
    }

    func initiateRefund() {
        pushLTRecoverFundsViewController(vm.transaction)
    }

    func pushLTRecoverFundsViewController(_ tx: Transaction) {
        let amount = tx.amounts["btc"].map {UInt64(abs($0))}
        let address = tx.inputs?.first?.address as? String
        let model = LTRecoverFundsViewModel(wallet: tx.subaccountItem,
                                            onChainAddress: address,
                                            amount: amount,
                                            type: .refund)
        let ltFlow = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = ltFlow.instantiateViewController(withIdentifier: "LTRecoverFundsViewController") as? LTRecoverFundsViewController {
            vc.viewModel = model
            vc.modalPresentationStyle = .overFullScreen
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension TxDetailsViewController: UITableViewDelegate, UITableViewDataSource {

    var sections: [TxDetailsSection] {
        return TxDetailsSection.allCases
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch sections[section] {
        case TxDetailsSection.status:
            return 1
        case TxDetailsSection.amount:
            return vm.assetAmountList.amounts.count
        case TxDetailsSection.info:
            return vm.txDetailsInfoCellModels.count
        case TxDetailsSection.actions:
            return vm.txDetailsActionCellModels.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case TxDetailsSection.status:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TxDetailsStatusCell.identifier, for: indexPath) as? TxDetailsStatusCell {
                cell.configure(model: vm.txDetailsStatusCellModel)
                cell.selectionStyle = .none
                return cell
            }
        case TxDetailsSection.amount:
            if vm.txDetailsAmountCellModels.count == 1 {
                if let cell = tableView.dequeueReusableCell(withIdentifier: TxDetailsAmountCell.identifier, for: indexPath) as? TxDetailsAmountCell {
                    cell.configure(model: vm.txDetailsAmountCellModels[indexPath.row], copyAmount: { _ in })
                    cell.selectionStyle = .none
                    return cell
                }
            } else {
                if let cell = tableView.dequeueReusableCell(withIdentifier: TxDetailsMultiAmountCell.identifier, for: indexPath) as? TxDetailsMultiAmountCell {
                    cell.configure(model: vm.txDetailsAmountCellModels[indexPath.row], copyAmount: { _ in })
                    cell.selectionStyle = .none
                    return cell
                }
            }
        case TxDetailsSection.info:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TxDetailsInfoCell.identifier, for: indexPath) as? TxDetailsInfoCell {
                cell.configure(model: vm.txDetailsInfoCellModels[indexPath.row]) { [weak self] value in
                    self?.didSelectInfoAt(indexPath.row)
                }
                cell.selectionStyle = .none
                return cell
            }
            
        case TxDetailsSection.actions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TxDetailsActionCell.identifier, for: indexPath) as? TxDetailsActionCell {
                cell.configure(model: vm.txDetailsActionCellModels[indexPath.row], isLast: vm.txDetailsActionCellModels.count - 1 == indexPath.row)
                cell.selectionStyle = .none
                return cell
            }
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == TxDetailsSection.info.rawValue {
            return UITableView.automaticDimension
        }
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == TxDetailsSection.info.rawValue && vm.txDetailsInfoCellModels.count > 0  {
            return UITableView.automaticDimension
        }
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            
        if indexPath.section == TxDetailsSection.actions.rawValue {
            return 54.0
        }
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == TxDetailsSection.info.rawValue && vm.txDetailsInfoCellModels.count > 0 {
            return tableDivider(.header)
        }
        return nil
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == TxDetailsSection.info.rawValue {
            return tableDivider(.footer)
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let txSection = TxDetailsSection(rawValue: indexPath.section) {
            
            switch txSection {
            case .amount:
                didSelectAmountAt(indexPath.row)
            case .actions:
                let action = vm.txDetailsActionCellModels[indexPath.row].action
                switch action {
                case .speedUp:
                    increaseFeeTapped()
                case .addNote:
                    editNote()
                case .shareTx:
                    share()
                case .explorer:
                    explorerAction()
                case .more:
                    moreDetails()
                case .refund:
                    initiateRefund()
                }
            default:
                break
            }
        }
    }
}

extension TxDetailsViewController: DialogEditViewControllerDelegate {

    func didSave(_ note: String) {
        guard let txhash = vm.transaction.hash else { return }
        self.startAnimating()
        Task {
            try? await vm.wallet.session?.session?.setTransactionMemo(txhash_hex: txhash, memo: note, memo_type: 0)
            self.vm.transaction.memo = note
            self.delegate?.onMemoEdit()
            self.stopAnimating()
            self.tableView.reloadData()
        }
    }

    func didClose() { }
}

extension TxDetailsViewController: DialogExplorerOptionsViewControllerDelegate {
    func didSelect(_ option: ExplorerOption) {
        openExplorer(option)
    }
}

extension TxDetailsViewController: DialogShareTxOptionViewControllerDelegate {
    func didSelect(_ option: TxShareOption) {
        openShare(option)
    }
}

extension TxDetailsViewController {
    
    func tableDivider(_ style: TableDividerStyle) -> UIView {
        

        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: .zero))
        section.backgroundColor = UIColor.clear
        
        let v = UIView(frame: .zero)
        v.backgroundColor = .white.withAlphaComponent(0.1)
        v.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(v)
        
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 40.0),
            v.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -40.0),
            v.heightAnchor.constraint(equalToConstant: 1.0)
        ])
        
        if style == .header {

            let top = vm.txDetailsAmountCellModels.count > 1 ? CGFloat(20) : CGFloat(8)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: section.topAnchor, constant: top),
                v.bottomAnchor.constraint(equalTo: section.bottomAnchor , constant: -18)
            ])
        } else {
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: section.topAnchor, constant: 10),
                v.bottomAnchor.constraint(equalTo: section.bottomAnchor , constant: 0)
            ])
        }

        return section
        
    }
}
