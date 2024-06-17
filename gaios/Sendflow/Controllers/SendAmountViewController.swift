import Foundation
import UIKit
import gdk
import greenaddress
import core


class SendAmountViewController: KeyboardViewController {

    @IBOutlet weak var infoBg: UIView!
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var infoIcon: UIImageView!
    @IBOutlet weak var lblError: UILabel!

    @IBOutlet weak var infoMultiBg: UIView!
    @IBOutlet weak var infoMultiView: UIView!
    @IBOutlet weak var infoMultiIcon: UIImageView!
    @IBOutlet weak var lblMultiError: UILabel!

    @IBOutlet weak var payRequestStack: UIStackView!
    @IBOutlet weak var lblPayRequestTitle: UILabel!
    @IBOutlet weak var lblMinMax: UILabel!

    @IBOutlet weak var textBg: UIView!
    @IBOutlet weak var amountField: UITextField!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var btnClear: UIButton!
    
    @IBOutlet weak var lblAvailable: UILabel!
    @IBOutlet weak var lblFiat: UILabel!
    @IBOutlet weak var btnSendall: UIButton!
    @IBOutlet weak var btnDenomination: UIButton!

    @IBOutlet weak var lblFeeTitle: UILabel!
    @IBOutlet weak var lblFeeRate: UILabel!
    @IBOutlet weak var btnChangeSpeed: UIButton!
    @IBOutlet weak var lblTime: UILabel!
    @IBOutlet weak var lblNtwFee: UILabel!

    @IBOutlet weak var lblSumTotalKey: UILabel!
    @IBOutlet weak var lblSumTotalValue: UILabel!
    @IBOutlet weak var totalsView: UIStackView!
    @IBOutlet weak var lblConversion: UILabel!
    
    @IBOutlet weak var redepositMultiStack: UIStackView!
    @IBOutlet weak var amountStack: UIStackView!
    @IBOutlet weak var actionsStack: UIStackView!

    @IBOutlet weak var totalsSeparator: UIView!
    @IBOutlet weak var totalsSumView: UIView!
    @IBOutlet weak var changeSpeedView: UIView!
    @IBOutlet weak var neworkFeeView: UIView!

    @IBOutlet weak var multiAssetCard: UIView!
    @IBOutlet weak var lblMultiAssetTitle: UILabel!
    @IBOutlet weak var iconsView: UIView!
    @IBOutlet weak var iconsStack: UIStackView!
    @IBOutlet weak var iconsStackWidth: NSLayoutConstraint!
    @IBOutlet weak var lblMultiAssetHint: UILabel!
    @IBOutlet weak var lblMultiAssetInfo: UILabel!

    @IBOutlet weak var redepositNoEditView: UIStackView!
    @IBOutlet weak var lblRedepositNoEdit: UILabel!
    
    private let iconW: CGFloat = 36.0
    var viewModel: SendAmountViewModel!
    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()

        lblFeeTitle.text = "id_network_fee".localized
        lblFeeRate.text = ""
        lblTime.text = ""
        lblNtwFee.text = ""
        lblSumTotalKey.text = "Total Spent"
        lblSumTotalValue.text = ""
        lblError.text = ""
        amountField.addTarget(self, action: #selector(SendAmountViewController.textFieldDidChange(_:)),
                                  for: .editingChanged)

        reload()
        reloadError(false)
        if viewModel.createTx.isLightning {
            reloadForLightning()
        }
    
        Task { [weak self] in
            await self?.viewModel?.loadFees()
            await self?.validate()
            if self?.viewModel.redeposit2faType != nil {
                self?.reload()
            }
            if let vm = self?.viewModel {
                self?.reloadError(vm.error != nil && (vm.createTx.satoshi ?? 0 > 0 || !vm.amountEditable))
            }
        }
        if viewModel.assetId != viewModel.session?.gdkNetwork.getFeeAsset() {
            [lblFiat, btnDenomination, lblConversion].forEach {
                $0?.isHidden = true
            }
        }
        [changeSpeedView, neworkFeeView].forEach {
            $0.isHidden = !viewModel.showFeesInTotals
        }
    }

    func reload() {
        reloadNavigationBar()
        configureRedeposit()
        reloadBalance()
        reloadAmount()
        reloadDenomination()
        reloadFee()
        reloadTotal()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if viewModel.amountEditable {
            amountField.becomeFirstResponder()
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
        title = "id_amount".localized
        btnNext.setTitle("id_next".localized, for: .normal)
        lblPayRequestTitle.text = "Payment request of".localized
        lblMultiAssetTitle.text = ""
        lblMultiAssetHint.text = "id_multiple_assets".localized
        lblMultiAssetInfo.text = "The amount can’t be changed.".localized
        lblRedepositNoEdit.text = "The amount can’t be changed.".localized
    }

    var btnNextEnabled: Bool = false {
        didSet {
            btnNext.isEnabled = btnNextEnabled
            btnNext.isUserInteractionEnabled = btnNextEnabled
            if btnNextEnabled {
                btnNext.setStyle(.primary)
            } else {
                btnNext.setStyle(.primaryGray)
            }
        }
    }
    var btnSendAllPressed: Bool = false {
        didSet {
            if btnSendAllPressed {
                btnSendall.setStyle(.underlineGray(txt: "id_send_all".localized))
            } else {
                btnSendall.setStyle(.underline(txt: "id_send_all".localized))
            }
        }
    }

    func setStyle() {
        textBg.cornerRadius = 4.0
        [infoBg, infoMultiBg].forEach {
            $0.cornerRadius = 4.0
        }
        [infoIcon, infoMultiIcon].forEach {
            $0.image = UIImage(named: "ic_lightning_info")!.maskWithColor(color: .white)
        }
        [lblError, lblMultiError].forEach {
            $0.setStyle(.txt)
        }
        [lblAvailable, lblFiat, lblFeeTitle, lblNtwFee, lblTime, lblConversion].forEach {
            $0?.setStyle(.txtCard)
        }
        btnSendall.setStyle(.underline(txt: "id_send_all".localized))
        btnDenomination.setStyle(.inline)
        btnDenomination.setTitleColor(.white, for: .normal)
        btnDenomination.titleLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
        btnChangeSpeed.setStyle(.underline(txt: "id_change_speed".localized))
        [lblSumTotalKey, lblSumTotalValue].forEach {
            $0?.setStyle(.txtBigger)
        }
        btnNextEnabled = false
        [lblPayRequestTitle].forEach {
            $0?.setStyle(.sectionTitle)
        }
        lblMinMax.setStyle(.txt)
        lblMinMax.text = ""

        [multiAssetCard].forEach {
            $0.cornerRadius = 4.0
        }
        lblMultiAssetHint.setStyle(.txtCard)
        lblMultiAssetInfo.setStyle(.txtCard)
        lblRedepositNoEdit.setStyle(.txtCard)
    }

    func configureRedeposit() {
        if viewModel.redeposit2faType != nil {
            btnNext.setTitle("Redeposit".localized, for: .normal)
            [lblAvailable, amountStack, actionsStack, totalsSeparator, totalsSumView, btnSendall, btnClear].forEach { $0?.isHidden = true }
            
        }
        switch viewModel.redeposit2faType {
        case .single:
            amountStack.isHidden = false
            actionsStack.isHidden = false
            redepositNoEditView.isHidden = false
            totalsSeparator.isHidden = false
            totalsSumView.isHidden = false
            redepositMultiStack.isHidden = true
        case .multi:
            redepositNoEditView.isHidden = true
            redepositMultiStack.isHidden = false
            configureMultiAssetIcons()
        case .none:
            redepositNoEditView.isHidden = true
            redepositMultiStack.isHidden = true
        }
    }

    func configureMultiAssetIcons() {
        for v in iconsStack.subviews { v.removeFromSuperview() }
        var icons = viewModel.getAssetIcons()
        icons = Array(icons.prefix(4))
        iconsStackWidth.constant = CGFloat(icons.count) * iconW - CGFloat(icons.count - 1) * 5.0
        setImages(icons)
        iconsView.isHidden = false
    }

    func setImages(_ images: [UIImage]) {
        for img in images {
            let imageView = UIImageView()
            imageView.image = img
            imageView.borderColor = UIColor.gBlackBg()
            imageView.borderWidth = 2.0
            imageView.layer.cornerRadius = iconW / 2.0
            imageView.layer.masksToBounds = true
            iconsStack.addArrangedSubview(imageView)
        }
    }
    @MainActor
    func reloadNavigationBar() {
        if viewModel.redeposit2faType != nil {
            title = "Re-enable 2FA".localized
        } else {
            if let titleView = Bundle.main.loadNibNamed("SendTitleView", owner: self, options: nil)?.first as? SendTitleView {
                let title = "\("id_send".localized) \(viewModel.assetInfo?.ticker ?? "")"
                titleView.configure(txt: title, image: viewModel.assetImage ?? UIImage())
                self.navigationItem.titleView = titleView
            }
        }
    }
    
    @MainActor
    func reloadError(_ error: Bool) {
        if error {
            btnNextEnabled = false
            lblError.text = viewModel.error?.localized
            lblMultiError.text = viewModel.error?.localized
            infoMultiBg.backgroundColor = UIColor.gRedWarn()
            infoBg.backgroundColor = UIColor.gRedWarn()
            infoMultiView.isHidden = false
            infoView.isHidden = false
        } else {
            btnNextEnabled = false
            if viewModel.createTx.satoshi != nil || viewModel.createTx.sendAll || viewModel.createTx.txType == .sweep || viewModel.createTx.txType == .redepositExpiredUtxos {
                btnNextEnabled = true
            }
            lblError.text = ""
            lblMultiError.text = ""
            infoMultiBg.backgroundColor = .clear
            infoBg.backgroundColor = .clear
            infoMultiView.isHidden = true
            infoView.isHidden = true
        }
    }

    @IBAction func btnClear(_ sender: Any) {
        amountField.text = ""
        viewModel.createTx.satoshi = nil
        lblFiat.text = "≈ \(viewModel.subamountText ?? "")"
        lblConversion.text = "≈ \(viewModel?.conversionText ?? "")"
        Task { [weak self] in
            await self?.validate()
            self?.reloadTotal()
            self?.reloadError(false)
            self?.btnNextEnabled = false
            self?.btnClear.isHidden = true
        }
    }

    @IBAction func btnChangeSpeed(_ sender: Any) {
        view.endEditing(true)
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendDialogFeeViewController") as? SendDialogFeeViewController {
            vc.viewModel = viewModel.sendDialogFeeViewModel()
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    @IBAction func btnNext(_ sender: Any) {
        presentSendTxConfirmViewController()
    }

    @MainActor
    func presentSendTxConfirmViewController() {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendTxConfirmViewController") as? SendTxConfirmViewController {
            vc.viewModel = viewModel.sendSendTxConfirmViewModel()
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func btnSendAll(_ sender: Any) {
        viewModel.sendAll.toggle()
        btnSendAllPressed = viewModel.sendAll
        if !viewModel.sendAll {
            viewModel.createTx.satoshi = nil
            reloadAmount()
        }
        Task { [weak self] in await self?.validate() }
    }

    @IBAction func btnDenomination(_ sender: Any) {
        // Disable for liquid asset
        if viewModel.assetId != viewModel.session?.gdkNetwork.getFeeAsset() {
            return
        }
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogInputDenominationViewController") as? DialogInputDenominationViewController {
            vc.viewModel = viewModel.dialogInputDenominationViewModel()
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    
    func reloadForLightning() {
        lblFeeTitle.isHidden = true
        lblFeeRate.isHidden = true
        lblNtwFee.isHidden = true
        btnChangeSpeed.isHidden = true
        lblSumTotalKey.isHidden = true
        lblSumTotalValue.isHidden = true
        lblTime.isHidden = true
        totalsView.isHidden = true
        btnSendall.isHidden = true
    }
    
    @MainActor
    func reloadBalance() {
        lblAvailable.text = "\("id_available".localized) \(viewModel.walletBalanceText ?? "")"
    }
    
    @MainActor
    func reloadAmount() {
        amountField.isUserInteractionEnabled = viewModel.amountEditable
        btnSendall.isUserInteractionEnabled = viewModel.sendAllEnabled
        amountField.text = viewModel.amountText ?? ""
        lblFiat.text = "≈ \(viewModel.subamountText ?? "")"
        lblConversion.text = "≈ \(viewModel?.conversionText ?? "")"
        if viewModel.sendAll {
            btnClear.isHidden = true
            amountField.textColor = UIColor.gW40()
        } else {
            btnClear.isHidden = !viewModel.amountEditable || amountField.text?.isEmpty ?? true
            amountField.textColor = .white
        }
        btnSendAllPressed = viewModel.sendAll
    
        payRequestStack.isHidden = true
        if viewModel.createTx.isLightning {
            if let minAmount = viewModel.createTx.addressee?.minAmount,
               let maxAmount = viewModel.createTx.addressee?.maxAmount {
                payRequestStack.isHidden = false
                lblMinMax.text = "\(minAmount) - \(maxAmount) sats"
            }
        }
    }
    
    @MainActor
    func reloadDenomination() {
        btnDenomination.setTitle(
            viewModel.isFiat ? viewModel?.fiatCurrency ?? "" : viewModel?.assetInfo?.ticker ?? "BTC",
            for: .normal)
    }

    @MainActor
    func reloadTotal() {
        lblSumTotalValue.text = viewModel?.totalText ?? ""
        lblConversion.text = "≈ \(viewModel?.conversionText ?? "")"
    }

    @MainActor
    func reloadFee() {
        lblFeeRate.text = viewModel?.feeRateText ?? ""
        lblTime.text = viewModel?.feeTimeText ?? ""
        lblNtwFee.text = viewModel?.feeText ?? ""
    }
    
    @IBAction func amountChanged(_ sender: Any) {
    }
    
    func validate() async {
        let task = viewModel.validate()
        switch await task?.result {
        case .success(_):
            break
        case .failure(let err):
            switch err {
            case TransactionError.invalid(let localizedDescription):
                DropAlert().error(message: localizedDescription)
            case GaError.ReconnectError, GaError.SessionLost, GaError.TimeoutError:
                DropAlert().error(message: "id_you_are_not_connected".localized)
            default:
                DropAlert().error(message: err.description() ?? "id_operation_failure".localized)
            }
        default:
            break
        }
        if viewModel.sendAll || viewModel.createTx.txType == .sweep {
            reloadAmount()
        }
        reloadError(viewModel.error != nil)
        reloadFee()
        reloadTotal()
    }
}

extension SendAmountViewController: DialogInputDenominationViewControllerDelegate {

    func didSelectFiat() {
        viewModel.isFiat = true
        reloadAmount()
        reloadBalance()
        reloadFee()
        reloadTotal()
        reloadNavigationBar()
        reloadDenomination()
    }

    func didSelectInput(denomination: DenominationType) {
        viewModel.denominationType = denomination
        viewModel.isFiat = false
        reloadAmount()
        reloadBalance()
        reloadFee()
        reloadTotal()
        reloadNavigationBar()
        reloadDenomination()
    }
}
extension SendAmountViewController {
    @objc func textFieldDidChange(_ textField: UITextField) {
        guard let text = amountField.text else { return }
        btnClear.isHidden = text.isEmpty
        if text.isEmpty {
            reloadError(false)
            btnNextEnabled = false
            return
        }
        let balance = viewModel.isFiat ? Balance.fromFiat(text) : Balance.from(text, assetId: viewModel.assetId, denomination: viewModel.denominationType)
        viewModel.createTx.satoshi = balance?.satoshi
        lblFiat.text = "≈ \(viewModel.subamountText ?? "")"
        lblConversion.text = "≈ \(viewModel?.conversionText ?? "")"
        Task { [weak self] in await self?.validate() }
    }
}
extension SendAmountViewController: SendDialogFeeViewControllerProtocol {
    func select(transactionPriority: gdk.TransactionPriority, feeRate: UInt64?) {
        viewModel.createTx.feeRate = feeRate
        viewModel.transactionPriority = transactionPriority
        reloadFee()
        reloadTotal()
        reloadAmount()
        Task { [weak self] in
            await self?.validate()
            self?.reloadAmount()
        }
    }
}
extension SendAmountViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField.text?.count ?? 0 > 15 {
            return false
        }
        return true
    }
}
