import Foundation
import BreezSDK
import UIKit
import LinkPresentation
import gdk
import hw
import Combine
import core

enum BuySection: Int, CaseIterable {
    case asset
    case account
    case amount
}

class BuyViewController: KeyboardViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var lblClaim: UILabel!

    private var headerH: CGFloat = 36.0
    var viewModel: BuyViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        register()
        setContent()
        setStyle()
        reload()
        
        AnalyticsManager.shared.buyInitiate(account: viewModel.wm.account)
        Task { [weak self] in await self?.asyncLoad() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillShow(notification: notification)
    }

    func register() {
        ["ReceiveAssetCell", "AssetToBuyCell", "AmountToBuyCell", "CreateAccountCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }

    func setContent() {
        title = "Buy".localized
        btnNext.setTitle("Buy with meld.io".localized, for: .normal)
        lblClaim.text = "Provided by meld.io".localized
        if viewModel.meld.isSandboxEnvironment {
            lblClaim.text = "\(lblClaim.text ?? "") Testnet"
        }
        let image = UIImage(named: "ic_squared_out_small")
        btnNext.setImage(image?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate), for: .normal)
        btnNext.tintColor = UIColor.white
    }

    func setStyle() {
        btnNext.setStyle(.primary)
        lblClaim.setStyle(.txtCard)
    }

    var sections: [BuySection] {
        return [.asset, .account, .amount]
    }

    func asyncLoad() async {
        try? await viewModel.load()
        await MainActor.run { tableView.reloadData() }
    }

    @MainActor
    func reload() {
        tableView.reloadData()
    }

    func presentDialogInputDenominations() {
        let model = viewModel.dialogInputDenominationViewModel()
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogInputDenominationViewController") as? DialogInputDenominationViewController {
            vc.viewModel = model
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func presentAccountAssetViewController() {
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountAssetViewController") as? AccountAssetViewController {
            vc.viewModel = viewModel.accountAssetViewModel(for: .BUY)
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func presentSecuritySelectViewController() {
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SecuritySelectViewController") as? SecuritySelectViewController {
            vc.viewModel = SecuritySelectViewModel(asset: "btc", onlyBtc: true)
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func btnNext(_ sender: Any) {
        Task.detached { [weak self] in
            let url = try await self?.viewModel.buy()
            await MainActor.run { [weak self] in
                AnalyticsManager.shared.buyRedirect(account: self?.viewModel.wm.account)
                SafeNavigationManager.shared.navigate(url)
            }
        }
    }
}

extension BuyViewController: AssetExpandableSelectViewControllerDelegate {
    func didSelectReceiver(assetId: String, account: WalletItem) {
        viewModel.asset = assetId
        viewModel.account = account
        reload()
    }
}

extension BuyViewController: AssetSelectViewControllerDelegate {
    func didSelectAnyAsset(_ type: AnyAssetType) {

        switch type {
        case .liquid:
            viewModel?.asset = AssetInfo.lbtcId
            reload()
        case .amp:
            break
        }
        navigationController?.popViewController(animated: true)
    }

    func didSelectAsset(_ assetId: String) {
        viewModel?.asset = assetId
        reload()
        navigationController?.popViewController(animated: true)
    }
}

extension BuyViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case BuySection.asset:
            return 1
        case BuySection.account:
            return 1
        case BuySection.amount:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case BuySection.asset:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AssetToBuyCell") as? AssetToBuyCell {
                cell.configure(model: AssetToBuyCellModel(assetId: "btc"))
                cell.selectionStyle = .none
                return cell
            }
        case BuySection.account:
            if let model = viewModel.assetCellModel {
                if let cell = tableView.dequeueReusableCell(withIdentifier: "ReceiveAssetCell") as? ReceiveAssetCell {
                    cell.configure(model: model, onTap: { [weak self] in Task {
                        self?.presentAccountAssetViewController()
                    } })
                    cell.selectionStyle = .none
                    return cell
                }
            } else {
                if let cell = tableView.dequeueReusableCell(withIdentifier: "CreateAccountCell") as? CreateAccountCell {
                    cell.configure(onTap: { [weak self] in Task {
                        self?.presentSecuritySelectViewController()
                    } })
                    cell.selectionStyle = .none
                    return cell
                }
            }
        case BuySection.amount:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AmountToBuyCell") as? AmountToBuyCell {
                let model = viewModel.amountCellModel
                cell.configure(model: model, delegate: self)
                cell.selectionStyle = .none
                return cell
            }
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sections[section] {
        case BuySection.asset, BuySection.account, BuySection.amount:
            return headerH
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case BuySection.asset:
            return headerView("Asset to buy".localized)
        case BuySection.account:
            return headerView("Account".localized)
        case BuySection.amount:
            return headerView("Amount".localized)
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
}

extension BuyViewController {
    func headerView(_ txt: String) -> UIView {
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = UIColor.gBlackBg()
        let title = UILabel(frame: .zero)
        title.setStyle(.sectionTitle)
        title.text = txt
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)
        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 25),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -25)
        ])
        return section
    }
}

extension BuyViewController: AmountToBuyCellDelegate {

    func onInputDenomination() {
        presentDialogInputDenominations()
    }

    func textFieldEnabled() {
        reload()
    }

    func textFieldDidChange(_ satoshi: Int64?, isFiat: Bool) {
        viewModel.satoshi = satoshi
        viewModel.isFiat = isFiat
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    func stateDidChange(_ state: AmountToBuyCellState) {
        viewModel.state = state
        btnNext.isEnabled = viewModel.account != nil && viewModel.state == .valid && viewModel.satoshi != nil
        btnNext.isUserInteractionEnabled = btnNext.isEnabled
        btnNext.setStyle( btnNext.isEnabled ? .primary : .primaryGray)
    }
}

extension BuyViewController: DialogInputDenominationViewControllerDelegate {


    func didSelectFiat() {
        viewModel.isFiat = true
        tableView.reloadData()
    }

    func didSelectInput(denomination: gdk.DenominationType) {
        viewModel.isFiat = false
        viewModel?.inputDenomination = denomination
        tableView.reloadData()
    }
}

extension BuyViewController: AccountAssetViewControllerDelegate {
    
    func didSelectAccountAsset(account: WalletItem, asset: AssetInfo) {
        viewModel.asset = asset.assetId
        viewModel.account = account
        tableView.reloadData()
    }
}

extension BuyViewController: SecuritySelectViewControllerDelegate {
    func didCreatedWallet(_ wallet: WalletItem) {
        if !wallet.networkType.liquid {
            viewModel.account = wallet
            tableView.reloadData()
        }
    }
}
