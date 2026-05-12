import Foundation
import UIKit
import gdk
import greenaddress
import core
import lightning

class SendAmountViewController: KeyboardViewController {

    @IBOutlet weak var infoBg: UIView!
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var infoIcon: UIImageView!
    @IBOutlet weak var lblError: UILabel!

    @IBOutlet weak var infoMultiBg: UIView!
    @IBOutlet weak var infoMultiView: UIView!
    @IBOutlet weak var infoMultiIcon: UIImageView!
    @IBOutlet weak var lblMultiError: UILabel!

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

    @IBOutlet weak var totalsView: UIStackView!

    @IBOutlet weak var redepositMultiStack: UIStackView!
    @IBOutlet weak var amountStack: UIStackView!
    @IBOutlet weak var actionsStack: UIStackView!

    @IBOutlet weak var changeSpeedView: UIView!
    //@IBOutlet weak var networkFeeView: UIView!

    @IBOutlet weak var multiAssetCard: UIView!
    @IBOutlet weak var lblMultiAssetTitle: UILabel!
    @IBOutlet weak var iconsView: UIView!
    @IBOutlet weak var iconsStack: UIStackView!
    @IBOutlet weak var iconsStackWidth: NSLayoutConstraint!
    @IBOutlet weak var lblMultiAssetHint: UILabel!
    @IBOutlet weak var lblMultiAssetInfo: UILabel!

    @IBOutlet weak var redepositNoEditView: UIStackView!
    @IBOutlet weak var lblRedepositNoEdit: UILabel!

    var viewModel: SendAmountViewModel!

    init?(coder: NSCoder, viewModel: SendAmountViewModel) {
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
        reload()
        viewModel.onStateChanged = { [weak self] in
            self?.reload()
        }
        amountField.addTarget(self, action: #selector(SendAmountViewController.textFieldDidChange(_:)),
                              for: .editingChanged)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Automatically open the keyboard when the view is about to appear
        amountField.becomeFirstResponder()
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            self.anchorBottom.constant = keyboardFrame.height - 20.0
            self.view.layoutIfNeeded()
        })
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillHide(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            self.anchorBottom.constant = 20.0
            self.view.layoutIfNeeded()
        })
    }

    func setContent() {
        title = "id_amount".localized
        btnNext.setTitle("id_next".localized, for: .normal)
        //lblPayRequestTitle.text = "id_payment_request_of".localized
        lblMultiAssetTitle.text = ""
        lblMultiAssetHint.text = "id_multiple_assets".localized
        lblMultiAssetInfo.text = "id_the_amount_cant_be_changed".localized
        lblRedepositNoEdit.text = "id_the_amount_cant_be_changed".localized
    }

    func reload() {
        // This controller does not support the redeposit multi-asset card variants.
        multiAssetCard.isHidden = true
        redepositMultiStack.isHidden = true
        redepositNoEditView.isHidden = true
        if viewModel.isLightningPayment {
            reloadLightning()
        } else if viewModel.isSwapTarget {
            reloadSwapTarget()
        }
        reloadNavigationBar()
        reloadError()
        btnNextEnabled = viewModel.canContinue
        btnSendAllPressed = viewModel.sendAll

        [lblFiat, btnDenomination].forEach {
            $0?.isHidden = viewModel.hasPrice == false
        }
        lblAvailable.text = "\(viewModel.availableLabel): \(viewModel.convertToText(viewModel.maxSendAmount ?? 0) ?? "")"
        btnDenomination.setTitle(viewModel.currencyOrTicker, for: .normal)
        if viewModel.hasPrice == false {
            [lblFiat, btnDenomination].forEach {
                $0?.isHidden = true
            }
        }

        reloadAmount()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if viewModel.amountEditable {
            amountField.becomeFirstResponder()
        }
    }

    var btnNextEnabled: Bool = false {
        didSet {
            btnNext.isEnabled = btnNextEnabled
            if btnNextEnabled {
                btnNext.setStyle(.primary)
            } else {
                btnNext.setStyle(.primaryDisabled)
            }
        }
    }

    var btnSendAllPressed: Bool = false {
        didSet {
            if btnSendAllPressed {
                btnSendall.setStyle(.underline(txt: "id_send_all".localized, color: UIColor.gW40()))
            } else {
                btnSendall.setStyle(.underline(txt: "id_send_all".localized, color: UIColor.gAccent()))
            }
        }
    }

    func setStyle() {
        textBg.setStyle(CardStyle.defaultStyle)
        [infoBg, infoMultiBg].forEach {
            $0.cornerRadius = 4.0
        }
        [infoIcon, infoMultiIcon].forEach {
            $0.image = UIImage(named: "ic_lightning_info")!.maskWithColor(color: .white)
        }
        [lblError, lblMultiError].forEach {
            $0.setStyle(.txt)
        }
        [lblAvailable, lblFiat, lblFeeTitle, lblNtwFee, lblTime].forEach {
            $0?.setStyle(.txtCard)
        }
        btnSendall.setStyle(.underline(txt: "id_send_all".localized, color: UIColor.gAccent()))
        btnDenomination.setStyle(.inline)
        btnDenomination.setTitleColor(.white, for: .normal)
        btnDenomination.titleLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
        btnChangeSpeed.setStyle(.underline(txt: "id_change_speed".localized, color: UIColor.gAccent()))
        btnNextEnabled = false
        [multiAssetCard].forEach {
            $0.cornerRadius = 4.0
        }
        lblMultiAssetHint.setStyle(.txtCard)
        lblMultiAssetInfo.setStyle(.txtCard)
        lblRedepositNoEdit.setStyle(.txtCard)
    }
    @MainActor
    func reloadNavigationBar() {
        if let titleView = Bundle.main.loadNibNamed("SendTitleView", owner: self, options: nil)?.first as? SendTitleView {
            titleView
                .configure(
                    txt: viewModel.screenTitle,
                    image: viewModel.assetImage ?? UIImage()
                )
            self.navigationItem.titleView = titleView
        }
    }

    @MainActor
    func reloadError() {
        lblError.isHidden = viewModel.error == nil
        lblMultiError.isHidden = viewModel.error == nil
        infoMultiView.isHidden = viewModel.error == nil
        infoView.isHidden = viewModel.error == nil
        infoMultiBg.backgroundColor = viewModel.error == nil ? .clear : UIColor.gRedWarn()
        infoBg.backgroundColor = viewModel.error == nil ? .clear : UIColor.gRedWarn()
        if let error = viewModel.error {
            lblError.text = error.description().localized
            lblMultiError.text = error.description().localized
        }
    }

    @IBAction func btnClear(_ sender: Any) {
        btnClear.isHidden = true
        amountField.text = ""
        viewModel.amountText = nil
        lblFiat.text = ""
        reload()
    }

    @IBAction func btnChangeSpeed(_ sender: Any) {
        view.endEditing(true)
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendDialogFeeViewController") as? SendDialogFeeViewController {
            //vc.viewModel = viewModel.sendDialogFeeViewModel()
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    @IBAction func btnNext(_ sender: Any) {
        viewModel.next()
    }

    @IBAction func btnSendAll(_ sender: Any) {
        viewModel.sendAll.toggle()
        btnSendAllPressed = viewModel.sendAll
        if !viewModel.sendAll {
            viewModel.amountText = nil
            reloadAmount()
        }
        viewModel.triggerValidation()
    }

    @IBAction func btnDenomination(_ sender: Any) {
        if AssetInfo.baseIds.contains(viewModel.assetId) {
            let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "DialogInputDenominationViewController") as? DialogInputDenominationViewController {
                vc.viewModel = viewModel.dialogInputDenominationViewModel()
                vc.delegate = self
                vc.modalPresentationStyle = .overFullScreen
                present(vc, animated: false, completion: nil)
            }
        } else {
            let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "DialogLiquidAssetToFiatViewController") as? DialogLiquidAssetToFiatViewController {
                vc.viewModel = viewModel.dialogLiquidAssetToFiatViewModel()
                vc.delegate = self
                vc.modalPresentationStyle = .overFullScreen
                present(vc, animated: false, completion: nil)
            }
        }
    }

    func reloadLightning() {
        lblFeeTitle.isHidden = true
        lblFeeRate.isHidden = true
        lblNtwFee.isHidden = true
        btnChangeSpeed.isHidden = true
        lblTime.isHidden = true
        totalsView.isHidden = true
        btnSendall.isHidden = true
        redepositMultiStack.isHidden = true
        redepositNoEditView.isHidden = true
    }

    // LNURL/BOLT12 on a Liquid subaccount: on-chain fee widgets do not apply
    // because the real fee comes from the swap preparation step on review.
    // Send-all is kept visible but dimmed to mirror the disabled view-model state.
    func reloadSwapTarget() {
        lblFeeTitle.isHidden = true
        lblFeeRate.isHidden = true
        lblNtwFee.isHidden = true
        btnChangeSpeed.isHidden = true
        lblTime.isHidden = true
        totalsView.isHidden = true
        btnSendall.isHidden = false
        btnSendall.alpha = 0.4
        redepositMultiStack.isHidden = true
        redepositNoEditView.isHidden = true
    }

    @MainActor
    func reloadAmount() {
        amountField.isUserInteractionEnabled = viewModel.amountEditable
        btnSendall.isUserInteractionEnabled = viewModel.sendAllEnabled
        //amountField.text = viewModel.amountText ?? ""
        lblFiat.isHidden = viewModel.satoshi == nil
        if viewModel.isFiat {
            lblFiat.text = "≈ \(viewModel.convertToDenom(viewModel.satoshi ?? 0) ?? "")"
        } else {
            lblFiat.text = "≈ \(viewModel.convertToFiat(viewModel.satoshi ?? 0) ?? "")"
        }
        if viewModel.sendAll {
            btnClear.isHidden = true
            amountField.textColor = UIColor.gW40()
        } else {
            btnClear.isHidden = !viewModel.amountEditable || viewModel.amountText == nil
            amountField.textColor = .white
        }
        btnSendAllPressed = viewModel.sendAll
    }
/*
    @MainActor
    func reloadFee() {
        lblFeeRate.text = viewModel?.feeRateText ?? ""
        lblTime.text = viewModel?.feeTimeText ?? ""
        lblNtwFee.text = viewModel?.feeText ?? ""
        lblFeeConvert.text = viewModel?.feeConvertText ?? ""
    }
*/
    @objc func triggerTextChange() {
        viewModel.triggerValidation()
    }

    func onLiquidAssetFiatChange() {
        reload()
    }
}

extension SendAmountViewController: DialogInputDenominationViewControllerDelegate {

    func didSelectFiat() {
        viewModel.isFiat = true
        if let satoshi = viewModel.satoshi {
            amountField.text = Balance
                .fromSatoshi(satoshi, assetId: viewModel.assetId)?
                .toFiat().0
        }
        viewModel.triggerValidation()
    }

    func didSelectInput(denomination: DenominationType) {
        viewModel.denominationType = denomination
        viewModel.isFiat = false
        if let satoshi = viewModel.satoshi {
            amountField.text = Balance
                .fromSatoshi(satoshi, assetId: viewModel.assetId)?
                .toDenom(denomination).0
        }
        viewModel.triggerValidation()
    }
}
extension SendAmountViewController {
    @objc func textFieldDidChange(_ textField: UITextField) {
        guard let text = amountField.text else { return }
        btnClear.isHidden = text.isEmpty
        viewModel.amountText = text
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.triggerTextChange), object: nil)
        perform(#selector(self.triggerTextChange), with: nil, afterDelay: 0.3)
    }
}
extension SendAmountViewController: SendDialogFeeViewControllerProtocol {
    func select(transactionPriority: gdk.TransactionPriority, feeRate: UInt64?) {
        //viewModel.createTx.feeRate = feeRate
        //viewModel.transactionPriority = transactionPriority
        reload()
        reloadAmount()
        Task { [weak self] in
            try await self?.viewModel.validate()
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
extension SendAmountViewController: DialogLiquidAssetToFiatViewControllerDelegate {
    func didSelectLiquidAsset() {
        viewModel.isFiat = false
        onLiquidAssetFiatChange()
    }
    func didSelectFiatConversion() {
        viewModel.isFiat = true
        onLiquidAssetFiatChange()
    }
}
