import Foundation
import UIKit

import core

class SendSwapViewController: UIViewController {
    @IBOutlet weak var container: UIStackView!
    @IBOutlet weak var cardFrom: UIStackView!
    @IBOutlet weak var lblFrom: UILabel!
    @IBOutlet weak var btnAccountFrom: UIButton!
    @IBOutlet weak var assetSelectorFrom: UIStackView!
    @IBOutlet weak var iconAssetFrom: UIImageView!
    @IBOutlet weak var lblAssetFrom: UILabel!
    @IBOutlet weak var fieldFrom: UITextField!
    @IBOutlet weak var btnDenomFrom: UIButton!
    @IBOutlet weak var lblAvailableFrom: UILabel!
    @IBOutlet weak var lblFiatFrom: UILabel!
    @IBOutlet weak var cardTo: UIStackView!
    @IBOutlet weak var lblTo: UILabel!
    @IBOutlet weak var btnAccountTo: UIButton!
    @IBOutlet weak var assetSelectorTo: UIStackView!
    @IBOutlet weak var iconAssetTo: UIImageView!
    @IBOutlet weak var lblAssetTo: UILabel!
    @IBOutlet weak var fieldTo: UITextField!
    @IBOutlet weak var btnDenomTo: UIButton!
    @IBOutlet weak var lblAvailableTo: UILabel!
    @IBOutlet weak var lblFiatTo: UILabel!
    @IBOutlet weak var btnSwap: UIButton!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var feesView: UIView!
    @IBOutlet weak var btnChangeSpeed: UIButton!
    @IBOutlet weak var lblFeesTime: UILabel!
    @IBOutlet weak var lblFeesRate: UILabel!
    @IBOutlet weak var iconError: UIImageView!
    @IBOutlet weak var bgError: UIView!
    @IBOutlet weak var lblError: UILabel!
    @IBOutlet weak var accountSelectorFrom: UIView!
    @IBOutlet weak var accountSelectorTo: UIView!
    
    let viewModel: SendSwapViewModel
    private var uiTask: Task<Void, Never>?
    private var state: SwapPositionState?
    var editingField: UITextField?

    init?(coder: NSCoder, viewModel: SendSwapViewModel) {
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
        setBindings()
        observeViewModel()
        NSLayoutConstraint.activate([
            btnNext.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16),
            btnNext.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        AnalyticsManager.shared.recordView(.sendSwap, sgmt: AnalyticsManager.shared.sessSgmt(WalletsStorage.shared.current))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.setupEstimators()
        
        if presentedViewController == nil {
            let fieldToFocus = editingField ?? fieldFrom
            fieldToFocus?.becomeFirstResponder()
        }
    }
    func resumeEditing() {
        editingField?.becomeFirstResponder()
    }
    func setError(_ visibility: Bool = false, msg: String? = nil) {
        let errorPosition = (self.state?.error as? SwapFlowError)?.position
        let isUnsupportedSwapPair = (self.state?.error as? SwapFlowError) == .unsupportedSwapPair
        
        if visibility {
            bgError.isHidden = false
            [container, bgError].forEach {
                $0?.backgroundColor = isUnsupportedSwapPair ? UIColor.gWarnCardBg() : UIColor.gRedSwapErr1()
                $0?.layer.borderColor = (isUnsupportedSwapPair ? UIColor.gWarnCardBorder() : UIColor.gRedSwapErr2()).cgColor
                $0?.layer.borderWidth = 1.0
                $0?.clipsToBounds = true
                $0?.cornerRadius = 5.0
            }
            container.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            bgError.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            bgError.clipsToBounds = true
            lblError.text = msg?.localized ?? ""
            iconError.image = UIImage(named: isUnsupportedSwapPair ? "ic_swap_warning" : "ic_swap_err")
            fieldFrom.textColor = errorPosition == .from ? UIColor.gRedSwapErr3() : UIColor.label
            fieldTo.textColor = errorPosition == .to ? UIColor.gRedSwapErr3() : UIColor.label
        } else {
            [container, bgError].forEach {
                $0?.backgroundColor = UIColor.clear
                $0?.layer.borderColor = UIColor.clear.cgColor
            }
            bgError.isHidden = true
            fieldFrom.textColor = UIColor.label
            fieldTo.textColor = UIColor.label
        }
    }

    private func observeViewModel() {
        // Initial state
        let initialState = viewModel.currentState()
        self.state = initialState
        self.reload(initialState)
        // Listen for stream of updates
        uiTask = Task { [weak self] in
            guard let self else { return }
            let updates = self.viewModel.stateUpdates()
            for await state in updates {
                await MainActor.run {
                    self.state = state
                    self.reload(state)
                }
            }
        }
    }

    deinit {
        uiTask?.cancel()
    }

    func setContent() {
        title = "id_swap".localized
        
        accountSelectorFrom.isUserInteractionEnabled = true
        accountSelectorTo.isUserInteractionEnabled = true
        let tapFrom = UITapGestureRecognizer(target: self, action: #selector(assetSelectorFromTapped))
        assetSelectorFrom.addGestureRecognizer(tapFrom)
        let tapTo = UITapGestureRecognizer(target: self, action: #selector(assetSelectorToTapped))
        assetSelectorTo.addGestureRecognizer(tapTo)
        
        btnNext.setTitle("id_continue".localized, for: .normal)
        btnChangeSpeed.setTitle("id_change_speed".localized, for: .normal)
        btnChangeSpeed.setStyle(.inline)
    }

    func reload(_ state: SwapPositionState) {
        // labels update
        lblFrom.text = state.from.title
        lblAssetFrom.text = state.from.assetName
        lblAvailableFrom.text = state.availableFrom
        lblFiatFrom.text = state.subamountFrom
        iconAssetFrom.image = state.from.assetIcon
        
        lblTo.text = state.to.title
        lblAssetTo.text = state.to.assetName
        lblAvailableTo.text = state.availableTo
        lblFiatTo.text = state.subamountTo
        iconAssetTo.image = state.to.assetIcon

        UIView.performWithoutAnimation {
            self.btnAccountFrom.setTitle(state.from.accountName, for: .normal)
            self.btnAccountTo.setTitle(state.to.accountName, for: .normal)
            
            self.btnAccountFrom.setStyle(self.viewModel.shouldShowSelector(state.from.assetId) ? .inline : .inlineDisabled)
            self.btnAccountFrom.isHidden = !self.viewModel.shouldShowSelector(state.from.assetId)
            
            self.btnAccountTo.setStyle(self.viewModel.shouldShowSelector(state.to.assetId) ? .inline : .inlineDisabled)
            self.btnAccountTo.isHidden = !self.viewModel.shouldShowSelector(state.to.assetId)
            
            self.btnAccountFrom.layoutIfNeeded()
            self.btnAccountTo.layoutIfNeeded()
        }
        
        lblFiatFrom.textColor = (state.from.amount ?? 0) == 0 ? .gGrayTxtDisabled() : .gGrayTxt()
        lblFiatTo.textColor = (state.to.amount ?? 0) == 0 ? .gGrayTxtDisabled() : .gGrayTxt()
        
        btnAccountFrom.titleLabel?.font = UIFont.systemFont(ofSize: 12.0)
        btnAccountTo.titleLabel?.font = UIFont.systemFont(ofSize: 12.0)
        iconAssetTo.image = state.to.assetIcon
        // error
        let errorMsg = state.error?.description().localized
        lblError.text = errorMsg ?? ""
        lblError.isHidden = state.error == nil
        setError(state.error != nil, msg: errorMsg)
        // fees
        let isFeeViewShown = state.route != .lnToBtc
        feesView.isHidden = !isFeeViewShown
        btnChangeSpeed.isHidden = !isFeeViewShown
        if isFeeViewShown {
            lblFeesTime.text = viewModel.feeRateTime()
            lblFeesRate.text = viewModel.feeRateText() ?? "-"
        }
        // textfield updates
        if !fieldFrom.isFirstResponder {
            fieldFrom.text = state.amountFrom ?? ""
        }
        if !fieldTo.isFirstResponder {
            fieldTo.text = state.amountTo ?? ""
        }
        // denominations
        UIView.performWithoutAnimation {
            if state.isFiat {
                self.btnDenomFrom.setTitle(state.currency, for: .normal)
                self.btnDenomTo.setTitle(state.currency, for: .normal)
            } else {
                self.btnDenomFrom.setTitle(state.from.assetSymbol(state.denomination), for: .normal)
                self.btnDenomTo.setTitle(state.to.assetSymbol(state.denomination), for: .normal)
            }
            self.btnDenomFrom.layoutIfNeeded()
            self.btnDenomTo.layoutIfNeeded()
        }
        let enabledNext = state.error == nil && state.from.amount != nil && state.to.amount != nil &&  state.from.amount != 0 && state.to.amount != 0
        btnNext.isEnabled = enabledNext
        btnNext.setStyle(enabledNext ? .primary : .primaryDisabled)
    }
    func setStyle() {
        [cardFrom, cardTo].forEach {
            $0?.setStyle(CardStyle.defaultStyle)
        }
        [lblFrom, lblTo].forEach {
            $0?.setStyle(.txtSmaller)
            $0?.textColor = .gGrayTxt()
        }
        [btnAccountFrom, btnAccountTo].forEach {
            $0?.setStyle(.inline)
            $0?.titleLabel?.font = UIFont.systemFont(ofSize: 12.0)
        }
        [lblAssetFrom, lblAssetTo].forEach {
            $0.setStyle(.txt)
            $0.font = UIFont.systemFont(ofSize: $0.font.pointSize, weight: .medium)
        }
        [fieldFrom, fieldTo].forEach {
            let placeholder = $0?.placeholder ?? "0"
            $0?.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [NSAttributedString.Key.foregroundColor: UIColor.gGrayTxtDisabled()]
            )
            $0?.font = UIFont.systemFont(ofSize: 16.0, weight: .medium)
        }
        [btnDenomFrom, btnDenomTo].forEach {
            $0?.setStyle(.inline)
            $0?.titleLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .medium)
            $0?.titleLabel?.lineBreakMode = .byClipping
        }
        [lblAvailableFrom, lblAvailableTo].forEach {
            $0?.setStyle(.txtSmaller)
            $0?.textColor = .gGrayTxt()
        }
        [lblFiatFrom, lblFiatTo].forEach {
            $0?.setStyle(.txtSmaller)
            $0?.textColor = . gGrayTxt()
        }
        [lblFeesTime, lblFeesRate].forEach {
            $0?.setStyle(.txtCard)
        }
        btnSwap.setStyle(.defaultStyle)
        btnNext.setStyle(.primary)
        lblError.setStyle(.txtSmaller)
    }
    func setBindings() {
        [fieldFrom, fieldTo].forEach {
            $0.addTarget(self, action: #selector(SendSwapViewController.textFieldDidChange(_:)),
                         for: .editingChanged)
        }
    }
    
    private func saveEditingFieldAndDismissKeyboard() {
        if fieldFrom.isFirstResponder {
            editingField = fieldFrom
        } else if fieldTo.isFirstResponder {
            editingField = fieldTo
        } else {
            editingField = nil
        }
        view.endEditing(true)
    }
    
    func presentChangeDenominationDialog(for position: SwapPositionEnum) {
        saveEditingFieldAndDismissKeyboard()
        guard let vm = viewModel.dialogInputDenominationViewModel(for: position) else { return }
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "DialogInputDenominationViewController") { coder in
            DialogInputDenominationViewController(coder: coder, model: vm)
        }
        vc.delegate = self
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: false, completion: nil)
    }
    
    func presentSelectAssetDialog(for direction: SwapPositionEnum) {
        saveEditingFieldAndDismissKeyboard()
        let viewModel = SwapAssetSelectorViewModel(swapDirection: direction)
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "SendSwapAssetSelectorViewController") { coder in
            SwapAssetSelectorViewController(coder: coder, viewModel: viewModel)
        }
        vc.delegate = self
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: false, completion: nil)
    }

    @IBAction func btnSwap(_ sender: Any) {
        viewModel.swapPositions(for: viewModel.lastEditedPosition)
    }
    
    @MainActor
    @IBAction func btnNext(_ sender: Any) {
        AnalyticsManager.shared.swapInitiate(wallet: WalletsStorage.shared.current,
                                             from: viewModel.currentState().from.chain,
                                             to: viewModel.currentState().to.chain)
        Task { [weak viewModel] in
            startLoader(message: "")
            await viewModel?.performSwap()
            stopLoader()
        }
    }
    
    @IBAction func btnAccountFrom(_ sender: Any) {
        saveEditingFieldAndDismissKeyboard()
        viewModel.selectAccount(for: .from)
    }
    
    @IBAction func btnAccountTo(_ sender: Any) {
        saveEditingFieldAndDismissKeyboard()
        viewModel.selectAccount(for: .to)
    }
    
    @IBAction func btnChangeFee(_ sender: Any) {
        saveEditingFieldAndDismissKeyboard()
        viewModel.selectFee()
    }
    
    @IBAction func btnDenomFrom(_ sender: Any) {
        presentChangeDenominationDialog(for: .from)
    }
    
    @IBAction func btnDenomTo(_ sender: Any) {
        presentChangeDenominationDialog(for: .to)
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        if textField == fieldFrom, let number = fieldFrom.text {
            viewModel.updateAmountFromText(number, for: .from)
        } else if textField == fieldTo, let number = fieldTo.text {
            viewModel.updateAmountFromText(number, for: .to)
        }
    }
    
    @objc func assetSelectorFromTapped() {
        presentSelectAssetDialog(for: .from)
        
    }
    
    @objc func assetSelectorToTapped() {
        presentSelectAssetDialog(for: .to)
    }
}
extension SendSwapViewController: SendFlowErrorDisplayable {
    func handleSendFlowError(_ error: Error?) {
        if let error = error {
            showError(error.description().localized)
        }
    }
}
extension SendSwapViewController: DialogInputDenominationViewControllerDelegate {
    func didSelectFiat() {
        fieldFrom.text = viewModel.newFiatText(position: .from)
        fieldTo.text = viewModel.newFiatText(position: .to)
        
        viewModel.updateIsFiat(true)
        let number = editingField ?? fieldFrom
        viewModel.updateAmountFromText(number?.text ?? "", for: viewModel.lastEditedPosition)
        resumeEditing()
    }
    func didSelectInput(denomination: DenominationType) {
        fieldFrom.text = viewModel.newText(position: .from, newDenom: denomination)
        fieldTo.text = viewModel.newText(position: .to, newDenom: denomination)
        
        viewModel.updateIsFiat(false)
        viewModel.updateDenomination(denomination)
        let number = editingField ?? fieldFrom
        viewModel.updateAmountFromText(number?.text ?? "", for: viewModel.lastEditedPosition)
        resumeEditing()
    }
    func didCancel() {
        resumeEditing()
    }
}

extension SendSwapViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        let fieldToFocus = editingField ?? fieldFrom
        fieldToFocus?.becomeFirstResponder()
    }
}

extension SendSwapViewController: SendSwapAssetSelectorViewControllerDelegate {
    func didSelectAsset(_ selector: SwapAssetSelectorViewController, didSelect asset: SwapAssetType) {
        viewModel.updateAssetType(asset, for: selector.viewModel.swapDirection)
        resumeEditing()
    }
    func didCancel(_ selector: SwapAssetSelectorViewController) {
        resumeEditing()
    }
}
