import Foundation
import UIKit
import gdk
import core
class SendSwapViewController: UIViewController {
    @IBOutlet weak var container: UIStackView!
    @IBOutlet weak var cardFrom: UIStackView!
    @IBOutlet weak var lblFrom: UILabel!
    @IBOutlet weak var btnAccountFrom: UIButton!
    @IBOutlet weak var iconAssetFrom: UIImageView!
    @IBOutlet weak var lblAssetFrom: UILabel!
    @IBOutlet weak var fieldFrom: UITextField!
    @IBOutlet weak var btnDenomFrom: UIButton!
    @IBOutlet weak var lblAvailableFrom: UILabel!
    @IBOutlet weak var lblFiatFrom: UILabel!
    @IBOutlet weak var cardTo: UIStackView!
    @IBOutlet weak var lblTo: UILabel!
    @IBOutlet weak var btnAccountTo: UIButton!
    @IBOutlet weak var iconAssetTo: UIImageView!
    @IBOutlet weak var lblAssetTo: UILabel!
    @IBOutlet weak var fieldTo: UITextField!
    @IBOutlet weak var btnDenomTo: UIButton!
    @IBOutlet weak var lblAvailableTo: UILabel!
    @IBOutlet weak var lblFiatTo: UILabel!
    @IBOutlet weak var btnSwap: UIButton!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var feesView: UIView!
    @IBOutlet weak var btnChangeSpeed: UIButton!
    @IBOutlet weak var lblFeesTime: UILabel!
    @IBOutlet weak var lblFeesRate: UILabel!
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
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        fieldFrom.becomeFirstResponder()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.setupEstimators()
    }
    func resumeEditing() {
        editingField?.becomeFirstResponder()
    }
    func setError(_ visibility: Bool = false, msg: String? = nil) {
        if visibility {
            bgError.isHidden = false
            [container, bgError].forEach {
                $0?.backgroundColor = UIColor.gRedSwapErr1()
                $0?.layer.borderColor = UIColor.gRedSwapErr2().cgColor
                $0?.layer.borderWidth = 1.0
                $0?.clipsToBounds = true
                $0?.cornerRadius = 5.0
            }
            container.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            bgError.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            bgError.clipsToBounds = true
            lblError.text = msg?.localized ?? ""
        } else {
            [container, bgError].forEach {
                $0?.backgroundColor = UIColor.clear
                $0?.layer.borderColor = UIColor.clear.cgColor
            }
            bgError.isHidden = true
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
        btnNext.setTitle("id_continue".localized, for: .normal)
        btnChangeSpeed.setStyle(.underline(txt: "id_change_speed".localized, color: UIColor.gAccent()))
    }

    func reload(_ state: SwapPositionState) {
        // labels update
        lblFrom.text = state.from.title
        btnAccountFrom.setTitle(state.from.accountName, for: .normal)
        lblAssetFrom.text = state.from.assetName
        lblAvailableFrom.text = state.availableFrom
        lblFiatFrom.text = state.subamountFrom
        iconAssetFrom.image = state.from.assetIcon
        lblTo.text = state.to.title
        btnAccountTo.setTitle(state.to.accountName, for: .normal)
        lblAssetTo.text = state.to.assetName
        lblAvailableTo.text = state.availableTo
        lblFiatTo.text = state.subamountTo
        iconAssetTo.image = state.to.assetIcon
        lblFeesTime.text = viewModel.feeRateTime()
        lblFeesRate.text = viewModel.feeRateText() ?? "-"
        btnAccountFrom.isHidden = !viewModel.shouldShowSelector(state.from.assetId)
        btnAccountTo.isHidden = !viewModel.shouldShowSelector(state.to.assetId)
        iconAssetTo.image = state.to.assetIcon
        // error
        let errorMsg = state.error?.description().localized
        lblError.text = errorMsg ?? ""
        lblError.isHidden = state.error == nil
        setError(state.error != nil, msg: errorMsg)
        // fees
        lblFeesTime.text = viewModel.feeRateTime()
        lblFeesRate.text = viewModel.feeRateText() ?? "-"
        // textfield updates
        if !fieldFrom.isFirstResponder {
            fieldFrom.text = state.amountFrom ?? ""
        }
        if !fieldTo.isFirstResponder {
            fieldTo.text = state.amountTo ?? ""
        }
        // denominations
        if state.isFiat {
            btnDenomFrom.setTitle(state.currency, for: .normal)
            btnDenomTo.setTitle(state.currency, for: .normal)
        } else {
            btnDenomFrom.setTitle(state.from.assetSymbol(state.denomination), for: .normal)
            btnDenomTo.setTitle(state.to.assetSymbol(state.denomination), for: .normal)
        }
        let enabledNext = state.error == nil && state.from.amount != nil && state.to.amount != nil &&  state.from.amount != 0 && state.to.amount != 0
        btnNext.isEnabled = enabledNext
        btnNext.setStyle(enabledNext ? .primary : .primaryDisabled )
    }
    func setStyle() {
        [cardFrom, cardTo].forEach {
            $0?.setStyle(CardStyle.defaultStyle)
        }
        [lblFrom, lblTo].forEach {
            $0?.setStyle(.txtCard)
        }
        [btnAccountFrom, btnAccountTo].forEach {
            $0?.setStyle(.inline)
        }
        [lblAssetFrom, lblAssetTo].forEach {
            $0?.setStyle(.txtBigger)
        }
        [fieldFrom, fieldTo].forEach {
            $0?.font = UIFont.systemFont(ofSize: 18.0, weight: .medium)
        }
        [btnDenomFrom, btnDenomTo].forEach {
            $0?.setStyle(.inline)
        }
        [lblAvailableFrom, lblAvailableTo].forEach {
            $0?.setStyle(.txtCard)
        }
        [lblFiatFrom, lblFiatTo].forEach {
            $0?.setStyle(.txtCard)
            $0?.alpha = 0.5
        }
        [lblFeesTime, lblFeesRate].forEach {
            $0?.setStyle(.txtCard)
        }
        btnSwap.backgroundColor = UIColor.gGrayCard()
        btnSwap.layer.cornerRadius = 5
        btnSwap.borderWidth = 1.0
        btnSwap.borderColor = UIColor.gGrayCardBorder()
        btnNext.setStyle(.primary)
        lblError.setStyle(.txt)
    }
    func setBindings() {
        [fieldFrom, fieldTo].forEach {
            $0.addTarget(self, action: #selector(SendSwapViewController.textFieldDidChange(_:)),
                         for: .editingChanged)
        }
    }
    @objc func textFieldDidChange(_ textField: UITextField) {
        if textField == fieldFrom, let number = fieldFrom.text {
            viewModel.updateAmountFromText(number, for: .from)
        } else if textField == fieldTo, let number = fieldTo.text {
            viewModel.updateAmountFromText(number, for: .to)
        }
    }
    func changeDenom(for position: SwapPositionEnum) {
        guard let vm = viewModel.dialogInputDenominationViewModel(for: position) else { return }
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogInputDenominationViewController") as? DialogInputDenominationViewController {
            vc.viewModel = vm
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnSwap(_ sender: Any) {
        viewModel.swapPositions(for: fieldFrom.isFirstResponder ? .from : .to)
    }
    @MainActor
    @IBAction func btnNext(_ sender: Any) {
        AnalyticsManager.shared.swapInitiate(account: AccountsRepository.shared.current,
                                             from: viewModel.currentState().from.chain,
                                             to: viewModel.currentState().to.chain)
        Task { [weak viewModel] in
            startLoader(message: "")
            await viewModel?.performSwap()
            stopLoader()
        }
    }
    @IBAction func btnAccountFrom(_ sender: Any) {
        viewModel.selectAccount(for: .from)
    }
    @IBAction func btnAccountTo(_ sender: Any) {
        viewModel.selectAccount(for: .to)
    }
    @IBAction func btnChangeFee(_ sender: Any) {
        if fieldFrom.isFirstResponder {
            editingField = fieldFrom
        } else if fieldTo.isFirstResponder {
            editingField = fieldTo
        } else {
            editingField = nil
        }
        view.endEditing(true)
        viewModel.selectFee()
    }
    @IBAction func btnDenomFrom(_ sender: Any) {
        changeDenom(for: .from)
    }
    @IBAction func btnDenomTo(_ sender: Any) {
        changeDenom(for: .to)
    }
}
extension SendSwapViewController: SendFlowErrorDisplayable {
    func handleSendFlowError(_ error: Error?) {
        if let error {
            showError(error.description().localized)
        }
    }
}
extension SendSwapViewController: DialogInputDenominationViewControllerDelegate {
    func didSelectFiat() {
        guard let position = viewModel.selectedPosition else { return }
        switch position {
        case .from:
            fieldFrom.text = viewModel.newFiatText(position: position)
        case .to:
            fieldTo.text = viewModel.newFiatText(position: position)
        }
        viewModel.updateIsFiat(true)
        let number = position == .from ? fieldFrom : fieldTo
        viewModel.updateAmountFromText(number?.text ?? "", for: position)
    }
    func didSelectInput(denomination: DenominationType) {
        guard let position = viewModel.selectedPosition else { return }
        switch position {
        case .from:
            fieldFrom.text = viewModel.newText(position: position, newDenom: denomination)
        case .to:
            fieldTo.text = viewModel.newText(position: position, newDenom: denomination)
        }
        viewModel.updateIsFiat(false)
        viewModel.updateDenomination(denomination)
        let number = position == .from ? fieldFrom : fieldTo
        viewModel.updateAmountFromText(number?.text ?? "", for: position)
    }
}

extension SendSwapViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        let fieldToFocus = editingField ?? fieldFrom
        fieldToFocus?.becomeFirstResponder()
    }
}
