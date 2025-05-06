import Foundation
import UIKit
import gdk
import greenaddress
import core
import BreezSDK
import lightning
import hw

enum ProviderState {
    case loading
    case valid
    case noquote
    case hidden
}
class BuyBTCViewController: KeyboardViewController {

    @IBOutlet weak var amountStack: UIStackView!
    @IBOutlet weak var providerStack: UIStackView!
    @IBOutlet weak var accountStack: UIStackView!

    @IBOutlet weak var lblSection1: UILabel!
    @IBOutlet weak var lblSection2: UILabel!
    @IBOutlet weak var lblSection3: UILabel!

    @IBOutlet weak var bgAmount: UIView!
    @IBOutlet weak var bgProvider: UIView!

    @IBOutlet weak var btnAmountClean: UIButton!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var lblFiat: UILabel!
    @IBOutlet weak var lblDenom: UILabel!
    @IBOutlet weak var tiersView: UIView!
    @IBOutlet weak var btnTier1: UIButton!
    @IBOutlet weak var btnTier2: UIButton!
    @IBOutlet weak var btnTier3: UIButton!
    @IBOutlet weak var bgIconProvider: UIView!
    @IBOutlet weak var lblIconProvider: UILabel!
    @IBOutlet weak var lblProvider: UILabel!
    @IBOutlet weak var btnAccount: UIButton!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var lblNoQuotes: UILabel!
    @IBOutlet weak var viewProvider: UIView!
    @IBOutlet weak var viewNoQuotes: UIView!
    @IBOutlet weak var viewLoading: UIView!
    @IBOutlet weak var denomLoader: UIActivityIndicatorView!

    @IBOutlet weak var bgBackup: UIView!
    @IBOutlet weak var lblTitleBackup: UILabel!
    @IBOutlet weak var lblHintBackup: UILabel!
    @IBOutlet weak var btnRightBackup: UIButton!
    @IBOutlet weak var btnLeftBackup: UIButton!
    @IBOutlet weak var btnsContainerBackup: UIStackView!
    @IBOutlet weak var iconWarnBackup: UIImageView!
    @IBOutlet weak var btnDismissBackup: UIButton!

    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    var viewModel: BuyBTCViewModel!
    var quotes = [MeldQuoteItem]()
    var selectedIndex = 0
    var providerState: ProviderState = .hidden
    weak var verifyOnDeviceViewController: HWDialogVerifyOnDeviceViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        loadNavigationBtns()
        amountTextField.addTarget(self, action: #selector(BuyBTCViewController.textFieldDidChange(_:)),
                                  for: .editingChanged)
        loadAddress()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // always nag even after dismiss
        BackupHelper.shared.cleanDismissedCache(walletId: viewModel.wm.account.id, position: .buy)
        reload()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            self.amountTextField.becomeFirstResponder()
        }
    }
    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            self.anchorBottom.constant = keyboardFrame.height - 20.0
        })
    }
    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            self.anchorBottom.constant = 20.0
        })
    }
    func setContent() {
        title = "Buy BTC".localized
        lblSection1.text = "Amount".localized
        lblSection2.text = "Exchange".localized
        lblSection3.text = "Account".localized
        btnNext.setTitle("Buy Bitcoin".localized, for: .normal)
        lblNoQuotes.text = "No quotes available for this amount".localized
    }
    func setStyle() {
        [bgAmount, bgProvider].forEach {
            $0.cornerRadius = 4.0
            $0.backgroundColor = UIColor.gGrayPanel()
        }
        [lblSection1, lblSection2, lblSection3].forEach {
            $0?.setStyle(.txtSectionHeader)
            $0?.textColor = UIColor.gGrayTxt()
        }
        [btnTier1, btnTier2, btnTier3].forEach {
            $0?.cornerRadius = 6.0
            $0?.backgroundColor = UIColor.gGrayPanel()
            $0?.setTitleColor(.white, for: .normal)
            $0?.titleLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .regular)
        }
        lblDenom.setStyle(.txtCard)
        lblFiat.setStyle(.txt)
        btnNext.setStyle(.primaryDisabled)
        lblNoQuotes.setStyle(.txtCard)
        bgIconProvider.cornerRadius = 15.0
        lblIconProvider.setStyle(.txtBold)
    }
    func setBackupCard() {
        bgBackup.layer.cornerRadius = 5.0
        bgBackup.borderWidth = 1
        bgBackup.backgroundColor = UIColor.gWarnCardBg()
        bgBackup.borderColor = UIColor.gWarnCardBorder()
        [btnLeftBackup, btnRightBackup].forEach {
            $0?.setStyle(.outlinedWhite)
        }
        btnLeftBackup.backgroundColor = .white
        btnLeftBackup.setTitleColor(UIColor.gBlackBg(), for: .normal)
        lblTitleBackup.setStyle(.txtBigger)
        lblHintBackup.setStyle(.txtCard)
        lblTitleBackup.text = "Back Up Your Wallet Now".localized
        lblHintBackup.text = "Don't lose access to your funds.".localized
        btnLeftBackup.setTitle("Backup Now".localized, for: .normal)
        btnRightBackup.isHidden = true
        iconWarnBackup.image = UIImage(named: "ic_card_warn")
        if BackupHelper.shared.needsBackup(walletId: viewModel.wm.account.id) && BackupHelper.shared.isDismissed(walletId: viewModel.wm.account.id, position: .buy) == false {
            bgBackup.isHidden = false
        } else {
            bgBackup.isHidden = true
        }
    }
    func reload() {
        viewProvider.isHidden = viewModel.showNoQuotes
        viewNoQuotes.isHidden = !viewModel.showNoQuotes
        accountStack.isHidden = !viewModel.showAccountSwitch
        lblFiat.text = viewModel.currency ?? ""
        tiersState()
        btnNext.setStyle(self.quotes.count == 0 ? .primaryDisabled : .primary)
        lblIconProvider.text = "PR"
        providerStack.isHidden = false
        lblDenom.alpha = 0.0
        viewProvider.isHidden = true
        viewNoQuotes.isHidden = true
        viewLoading.isHidden = true
        denomLoader.isHidden = true
        switch providerState {
        case .loading:
            viewLoading.isHidden = false
            denomLoader.isHidden = false
        case .valid:
            viewProvider.isHidden = false
            lblDenom.alpha = 1.0
        case .noquote:
            viewNoQuotes.isHidden = false
        case .hidden:
            providerStack.isHidden = true
        }
        if quotes.count != 0 {
            let pName = quotes[selectedIndex].serviceProvider
            lblProvider.text = pName
            lblProvider.setStyle(.txtBold)
            self.lblIconProvider.text = pName
            let initials = viewModel.getInitials(from: pName)
            lblIconProvider.text = initials
            bgIconProvider.backgroundColor = viewModel.colorFromProviderName(pName)
            lblDenom.text = "\(String(format: "%.8f", quotes[selectedIndex].destinationAmount)) BTC"
        }
        btnAccount.setTitle(viewModel.account.localizedName, for: .normal)
        setBackupCard()
    }
    func tiersState() {
        guard let tiers = viewModel.tiers else {
            tiersView.isHidden = true
            return
        }
        tiersView.isHidden = false
        btnTier1.setTitle(tiers.minStr, for: .normal)
        btnTier2.setTitle(tiers.midStr, for: .normal)
        btnTier3.setTitle(tiers.maxStr, for: .normal)
        [btnTier1, btnTier2, btnTier3].forEach {
            $0?.backgroundColor = UIColor.gGrayPanel()
        }
        let color = UIColor.gWarnCardBgBlue()
        if let amount = Double(amountTextField.text ?? "") {
            if amount == tiers.min {
                btnTier1?.backgroundColor = color
            }
            if amount == tiers.mid {
                btnTier2?.backgroundColor = color
            }
            if amount == tiers.max {
                btnTier3?.backgroundColor = color
            }
        }
    }
    func loadNavigationBtns() {
        var items = [UIBarButtonItem]()
        if viewModel.isJade {
            let verifyAddressBtn = UIButton(type: .system)
            verifyAddressBtn.setImage(UIImage(named: "ic_buy_circle_dots"), for: .normal)
            verifyAddressBtn.addTarget(self, action: #selector(onMoreActions), for: .touchUpInside)
            items.append(UIBarButtonItem(customView: verifyAddressBtn))
        }
        let countryBtn = UIButton(type: .system)
        countryBtn.contentEdgeInsets = UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
        countryBtn.setBackgroundImage(UIImage(named: "ic_buy_circle_empty"), for: .normal)
        countryBtn.addTarget(self, action: #selector(onCountry), for: .touchUpInside)
        countryBtn.setTitle(viewModel.countryCode(), for: .normal)
        countryBtn.titleLabel?.font = UIFont.systemFont(ofSize: 10.0, weight: .medium)
        items.append(UIBarButtonItem(customView: countryBtn))
        navigationItem.rightBarButtonItems = items
    }
    func loadQuotes() {
        Task { [weak self] in
            await self?.load()
        }
    }
    func loadAddress() {
        viewModel.address = nil
        Task {
            if let address = try? await viewModel.account.session?.getReceiveAddress(subaccount: viewModel.account.pointer) {
                viewModel.address = address
            }
        }
    }
    private func load() async {
        btnNext.setStyle(.primaryDisabled)
        quotes = []
        selectedIndex = 0
        guard let amountStr = amountTextField.text else { return }
        if amountStr.isEmpty {
            providerState = .hidden
            reload()
            return
        }
        let task = Task.detached { [weak self] in
            return try await self?.viewModel.quote(amountStr)
        }
        let result = await task.result
        switch result {
        case .success(let quotes):
            providerState = quotes?.count ?? 0 > 0 ? .valid : .noquote
            processQuotes(quotes)
        case .failure:
            providerState = .noquote
            reload()
        }
    }
    private func processQuotes(_ quotes: [MeldQuoteItem]?) {
        self.quotes = (quotes ?? []).sorted(by: { $0.destinationAmount > $1.destinationAmount })
        self.selectedIndex = 0
        self.reload()
    }
    @objc func triggerTextChange() {
        providerState = .loading
        loadQuotes()
        reload()
    }
    @objc func onMoreActions() {
        let storyboard = UIStoryboard(name: "BuyBTCFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "MoreActionsViewController") as? MoreActionsViewController {
            vc.viewModel = MoreActionsViewModel()
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }
    @objc func onCountry() {
        let storyboard = UIStoryboard(name: "BuyBTCFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SelectCountryViewController") as? SelectCountryViewController {
            vc.viewModel = SelectCountryViewModel()
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }
    func selectProvider(_ quote: MeldQuoteItem) {
        guard let amountStr = amountTextField.text else { return }
        view.endEditing(true)
        startLoader(message: String(format: "Connecting to %@", quote.serviceProvider))
        Task { [weak self] in
            await self?.widget(quote: quote, amountStr: amountStr)
            self?.stopLoader()
        }
    }
    @MainActor
    func presentConnectViewController() {
        let storyboard = UIStoryboard(name: "HWDialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "HWDialogConnectViewController") as? HWDialogConnectViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    private func widget(quote: MeldQuoteItem, amountStr: String) async {
        let task = Task.detached { [weak self] in
            return try await self?.viewModel.widget(quote: quote, amountStr: amountStr)
        }
        let result = await task.result
        switch result {
        case .success(let url):
            proceedWithWidget(url: url, quote: quote)
        case .failure(let error):
            handleError(error)
        }
    }
    private func handleError(_ error: Error) {
        showError(error.description()?.localized ?? error.localizedDescription)
    }
    func proceedWithWidget(url: String?, quote: MeldQuoteItem) {
        AnalyticsManager.shared.buyRedirect(account: self.viewModel.wm.account)
        SafeNavigationManager.shared.navigate(url, exitApp: false, title: quote.serviceProvider)
    }
    func verifySingleAddress() async {
        AnalyticsManager.shared.verifyAddressJade(account: AccountsRepository.shared.current, walletItem: viewModel.account)
        if let vm = viewModel.verifyOnDeviceViewModel() {
            presentVerifyOnDeviceViewController(viewModel: vm)
        }
        let task = Task.detached { [weak self] in
            try await self?.viewModel.validateHW()
        }
        switch await task.result {
        case .success(let success):
            verifyOnDeviceViewController?.dismiss()
            switch success {
            case .some(true):
                DropAlert().success(message: "id_the_address_is_valid".localized)
            case .none:
                DropAlert().error(message: "id_operation_failure".localized)
            case .some(false):
                DropAlert().error(message: "id_the_addresses_dont_match".localized)
            }
        case .failure(let error):
            verifyOnDeviceViewController?.dismiss()
            DropAlert().error(message: error.description()?.localized ?? "")
        }
    }
    @MainActor
    func dismissVerifyOnDeviceViewController() async {
        await verifyOnDeviceViewController?.dismissAsync(animated: true)
    }
    @MainActor
    func presentVerifyOnDeviceViewController(viewModel: HWDialogVerifyOnDeviceViewModel) {
        let storyboard = UIStoryboard(name: "HWDialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "HWDialogVerifyOnDeviceViewController") as? HWDialogVerifyOnDeviceViewController {
            vc.viewModel = viewModel
            verifyOnDeviceViewController = vc
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    @IBAction func btnTier1(_ sender: Any) {
        amountTextField.text = viewModel.tiers?.minStr
        triggerTextChange()
    }
    @IBAction func btnTier2(_ sender: Any) {
        amountTextField.text = viewModel.tiers?.midStr
        triggerTextChange()
    }
    @IBAction func btnTier3(_ sender: Any) {
        amountTextField.text = viewModel.tiers?.maxStr
        triggerTextChange()
    }
    @IBAction func btnAmountClean(_ sender: Any) {
        amountTextField.text = ""
        loadQuotes()
        reload()
    }
    @IBAction func btnProvider(_ sender: Any) {
        if self.quotes.count == 0 { return }
        bgProvider.pressAnimate {
            let storyboard = UIStoryboard(name: "BuyBTCFlow", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "SelectProviderViewController") as? SelectProviderViewController {
                vc.viewModel = SelectProviderViewModel(quotes: self.quotes)
                vc.delegate = self
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    @IBAction func btnAccount(_ sender: Any) {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAccountsViewController") as? DialogAccountsViewController {
            vc.viewModel = viewModel.dialogAccountsModel
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }
    @IBAction func btnNext(_ sender: Any) {
        if quotes.count != 0 {
            selectProvider(quotes[selectedIndex])
        }
    }

    @IBAction func btnBackup(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Recovery", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "RecoveryCreateViewController") as? RecoveryCreateViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    @IBAction func btnBackupAlertDismiss(_ sender: Any) {
        BackupHelper.shared.addToDismissed(walletId: viewModel.wm.account.id, position: .buy)
        bgBackup.isHidden = true
    }
}
extension BuyBTCViewController {
    @objc func textFieldDidChange(_ textField: UITextField) {
        guard amountTextField.text != nil else { return }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.triggerTextChange), object: nil)
        perform(#selector(self.triggerTextChange), with: nil, afterDelay: 0.7)
    }
}
extension BuyBTCViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField.text?.count ?? 0 > 15 {
            return false
        }
        return true
    }
}
extension BuyBTCViewController: SelectProviderViewControllerDelegate {
    func didSelectIndexQuoteAtIndex(_ index: Int) {
        selectedIndex = index
        reload()
    }
}
extension BuyBTCViewController: DialogAccountsViewControllerDelegate {
    func didSelectAccount(_ walletItem: gdk.WalletItem?) {
        if let walletItem {
            viewModel.account = walletItem
            loadAddress()
            reload()
        }
    }
}
extension BuyBTCViewController: SelectCountryViewControllerDelegate {
    func didSelectCountry(_ country: Country) {
        viewModel.persistCountry(country.code)
        loadNavigationBtns()
    }
}
extension BuyBTCViewController: MoreActionsViewControllerDelegate {
    func didSelectAction(_ indexPath: IndexPath) {
        if indexPath.row == 0 {
            presentConnectViewController()
        }
    }
}

extension BuyBTCViewController: HWDialogConnectViewControllerDelegate {
    func connected() {
    }

    func logged() {
        Task { [weak self] in
            await self?.verifySingleAddress()
        }
    }

    func cancel() {
        showError(HWError.Abort("id_cancel"))
    }

    func failure(err: Error) {
        showError(err)
    }
}
