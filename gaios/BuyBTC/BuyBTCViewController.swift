import Foundation
import UIKit
import gdk
import greenaddress
import core
import BreezSDK
import lightning

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

    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    var viewModel: BuyBTCViewModel!
    var quotes = [MeldQuoteItem]()
    var selectedIndex = 0
    var providerState: ProviderState = .hidden
    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        loadNavigationBtns()
        amountTextField.addTarget(self, action: #selector(BuyBTCViewController.textFieldDidChange(_:)),
                                  for: .editingChanged)
        reload()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        lblSection2.text = "Provider".localized
        lblSection3.text = "Account".localized
        btnNext.setTitle("Buy Bitcoin", for: .normal)
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
    func reload() {
        viewProvider.isHidden = viewModel.showNoQuotes
        viewNoQuotes.isHidden = !viewModel.showNoQuotes
        accountStack.isHidden = !viewModel.showAccountSwitch
        lblFiat.text = viewModel.fiatCurrency
        tiersState()
        btnNext.setStyle(self.quotes.count == 0 ? .primaryDisabled : .primary)
        lblIconProvider.text = "PR"
        providerStack.isHidden = false
        lblDenom.alpha = 1.0
        viewProvider.isHidden = true
        viewNoQuotes.isHidden = true
        viewLoading.isHidden = true
        denomLoader.isHidden = true
        switch providerState {
        case .loading:
            viewLoading.isHidden = false
            denomLoader.isHidden = false
            lblDenom.alpha = 0.0
        case .valid:
            viewProvider.isHidden = false
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
        }
        btnAccount.setTitle(viewModel.account.localizedName, for: .normal)
    }
    func tiersState() {
        btnTier1.setTitle(viewModel.tiers.minStr, for: .normal)
        btnTier2.setTitle(viewModel.tiers.midStr, for: .normal)
        btnTier3.setTitle(viewModel.tiers.maxStr, for: .normal)
        [btnTier1, btnTier2, btnTier3].forEach {
            $0?.backgroundColor = UIColor.gGrayPanel()
        }
        let color = UIColor.gWarnCardBgBlue()
        if let amount = Double(amountTextField.text ?? "") {
            if amount == viewModel.tiers.min {
                btnTier1?.backgroundColor = color
            }
            if amount == viewModel.tiers.mid {
                btnTier2?.backgroundColor = color
            }
            if amount == viewModel.tiers.max {
                btnTier3?.backgroundColor = color
            }
        }
    }
    func loadNavigationBtns() {
        var items = [UIBarButtonItem]()
        // TODO: remove not "!"
        if !viewModel.isJade {
            let verifyAddressBtn = UIButton(type: .system)
            verifyAddressBtn.setImage(UIImage(named: "ic_buy_circle_dots"), for: .normal)
            verifyAddressBtn.addTarget(self, action: #selector(onMoreActions), for: .touchUpInside)
            items.append(UIBarButtonItem(customView: verifyAddressBtn))
        }
        let countryBtn = UIButton(type: .system)
        countryBtn.contentEdgeInsets = UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
        countryBtn.setBackgroundImage(UIImage(named: "ic_buy_circle_empty"), for: .normal)
        countryBtn.addTarget(self, action: #selector(onCountry), for: .touchUpInside)
        countryBtn.setTitle(viewModel.countryCode, for: .normal)
        countryBtn.titleLabel?.font = UIFont.systemFont(ofSize: 10.0, weight: .medium)
        items.append(UIBarButtonItem(customView: countryBtn))
        navigationItem.rightBarButtonItems = items
    }
    func loadQuotes() {
        Task { [weak self] in
            await self?.load()
        }
    }

    private func load() async {
        guard let amountStr = amountTextField.text else { return }
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
    @IBAction func btnTier1(_ sender: Any) {
        amountTextField.text = viewModel.tiers.minStr
        triggerTextChange()
    }
    @IBAction func btnTier2(_ sender: Any) {
        amountTextField.text = viewModel.tiers.midStr
        triggerTextChange()
    }
    @IBAction func btnTier3(_ sender: Any) {
        amountTextField.text = viewModel.tiers.maxStr
        triggerTextChange()
    }
    @IBAction func btnAmountClean(_ sender: Any) {
        amountTextField.text = ""
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
        print("TO DO UPDATE ACCOUNT")
    }
}
extension BuyBTCViewController: SelectCountryViewControllerDelegate {
    func didSelectIndexPath(_ indexPath: IndexPath) {
        print("TO DO UPDATE COUNTRY")
    }
}
extension BuyBTCViewController: MoreActionsViewControllerDelegate {
    func didSelectAction(_ indexPath: IndexPath) {
        if indexPath.row == 0 {
            // open dialog verify address
        }
    }
}
