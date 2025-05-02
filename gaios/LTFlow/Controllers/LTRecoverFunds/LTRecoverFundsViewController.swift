import Foundation
import UIKit
import BreezSDK
import gdk
import greenaddress
import core

enum LTRecoverFundsType {
    case sweep
    case refund
    case sendAll
}

struct LTRecoverFundsViewModel {
    var wallet: WalletItem?
    var address: String?
    var onChainAddress: String?
    var amount: UInt64?
    var type: LTRecoverFundsType
    var feeSlider: Int = 0
    var session: LightningSessionManager? { wallet?.lightningSession }
    var recommendedFees: RecommendedFees?
    var currentFee: UInt64? {
        if let fees = recommendedFees {
            let rules = [fees.economyFee, fees.hourFee, fees.halfHourFee, fees.fastestFee]
            return rules[feeSlider]
        }
        return recommendedFees?.economyFee
    }
    var error: String?
    var fee: UInt64?
    var amountToBeRefunded: UInt64?
    var feeAmountRate: String? { feeRateWithUnit((currentFee ?? 0) * 1000) }
    func feeRateWithUnit(_ value: UInt64) -> String {
        let feePerByte = Double(value) / 1000.0
        return String(format: "%.2f sats / vbyte", feePerByte)
    }
    var amountText: String { Balance.fromSatoshi(amount ?? 0, assetId: AssetInfo.btcId)?.toText() ?? "" }
    var fiatText: String { Balance.fromSatoshi(amount ?? 0, assetId: AssetInfo.btcId)?.toFiatText() ?? "" }
    var amountToBeRefundedText: String { Balance.fromSatoshi(amountToBeRefunded ?? 0, assetId: AssetInfo.btcId)?.toText() ?? "" }
    var amountToBeRefundedFiatText: String { Balance.fromSatoshi(amountToBeRefunded ?? 0, assetId: AssetInfo.btcId)?.toFiatText() ?? "" }
    var feeText: String { Balance.fromSatoshi(fee ?? 0, assetId: AssetInfo.btcId)?.toText() ?? "" }
    var feeFiatText: String { Balance.fromSatoshi(fee ?? 0, assetId: AssetInfo.btcId)?.toFiatText() ?? "" }
    var maxReverseSwapAmount: UInt64?

    func recover() async throws {
        guard let lightBridge = session?.lightBridge else { return }
        guard let address = address else { throw BreezSDK.SdkError.Generic(message: "id_invalid_address") }
        switch type {
        case .refund:
            guard let onChainAddress = onChainAddress else { throw BreezSDK.SdkError.Generic(message: "id_invalid_address") }
            let fee = currentFee.map {UInt32($0)}
            _ = try await lightBridge.refund(swapAddress: onChainAddress, toAddress: address, satPerVbyte: fee)
        case .sweep:
            let fee = currentFee.map {UInt32($0)}
            _ = try await lightBridge.sweep(toAddress: address, satPerVbyte: fee)
        case .sendAll:
            _ = try await lightBridge.sendAllOnChain(toAddress: address, satPerVbyte: currentFee)
            AnalyticsManager.shared.emptiedAccount = wallet
        }
    }

    mutating func prepare() async {
        do {
            try await _prepare()
            error = nil
        } catch {
            self.error = error.description()
        }
    }

    mutating func _prepare() async throws {
        guard let lightBridge = session?.lightBridge else { return }
        if recommendedFees == nil {
            recommendedFees = await lightBridge.recommendedFees()
        }
        if maxReverseSwapAmount == nil {
            maxReverseSwapAmount = await lightBridge.maxReverseSwapAmount()
        }
        guard let currentFee = currentFee else {
            throw BreezSDK.SdkError.Generic(message: "Invalid fee")
        }
        switch type {
        case .refund:
            if let swapAddress = onChainAddress, let address = address {
                let res = try await lightBridge.prepareRefund(swapAddress: swapAddress, toAddress: address, satPerVbyte: UInt32(currentFee))
                if amount ?? 0 < res?.refundTxFeeSat ?? 0 {
                    throw BreezSDK.SdkError.Generic(message: "id_insufficient_funds")
                }
                amountToBeRefunded = (amount ?? 0) - (res?.refundTxFeeSat ?? 0)
                fee = res?.refundTxFeeSat ?? 0
            }
        case .sweep:
            if let address = address {
                let res = try await lightBridge.prepareSweep(toAddress: address, satPerVbyte: UInt32(currentFee))
                if amount ?? 0 < res?.txFeeSat ?? 0 {
                    throw BreezSDK.SdkError.Generic(message: "id_insufficient_funds")
                }
                amountToBeRefunded = (amount ?? 0) - (res?.txFeeSat ?? 0)
                fee = res?.txFeeSat
            }
        case .sendAll:
            if let address = address {
                try await lightBridge.prepareSendAllOnChain(toAddress: address, satPerVbyte: currentFee)
            }
        }
    }
}

class LTRecoverFundsViewController: KeyboardViewController {

    enum LTRecoverFundsSection: Int, CaseIterable {
        case address
        case amount
        case fee
        case summary
        case error
    }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var squareSliderView: SquareSliderView!

    private var headerH: CGFloat = 36.0

    var viewModel: LTRecoverFundsViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        prepare()
    }

    func setContent() {
        switch viewModel.type {
        case .refund:
            title = "id_refund".localized
        case .sweep:
            title = "id_sweep".localized
        case .sendAll:
            title = "Empty Lightning Account".localized
        }
        squareSliderView.delegate = self
    }

    func setStyle() {
        btnNextIsEnabled = false
    }

    var btnNextIsEnabled: Bool {
        get { squareSliderView.isUserInteractionEnabled }
        set { squareSliderView.isUserInteractionEnabled = newValue }
    }

    override func keyboardWillHide(notification: Notification) {
        if keyboardDismissGesture != nil {
            view.removeGestureRecognizer(keyboardDismissGesture!)
            keyboardDismissGesture = nil
        }
        tableView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: true)
    }

    func prepare() {
        Task { [weak self] in
            await self?.viewModel.prepare()
            await MainActor.run { self?.tableView.reloadData() }
        }
    }

    func send() {
        startAnimating()
        Task { [weak self] in
            do {
                try await self?.viewModel.recover()
                self?.success()
            } catch {
                self?.failure(error)
            }
       }
    }

    @MainActor
    func failure(_ error: Error) {
        stopAnimating()
        squareSliderView.reset()
        presentSendFailViewController(error)
    }

    @MainActor
    func presentSendFailViewController(_ error: Error) {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendFailViewController") as? SendFailViewController {
            vc.delegate = self
            vc.error = error
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    @MainActor
    func success() {
        stopAnimating()
        let storyboard = UIStoryboard(name: "Alert", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AlertViewController") as? AlertViewController {
            switch viewModel.type {
            case .refund:
                vc.viewModel = AlertViewModel(title: "id_refund".localized,
                                              hint: "id_refund_in_progress".localized)
            case .sweep:
                vc.viewModel = AlertViewModel(title: "id_sweep".localized,
                                              hint: "id_transaction_sent".localized)
            case .sendAll:
                vc.viewModel = AlertViewModel(title: "Empty Lightning Account".localized,
                                              hint: "id_transaction_sent".localized)
            }
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
    @MainActor
    func presentDialogErrorViewController(error: Error, paymentHash: String?) {
        let request = ZendeskErrorRequest(
            error: error.description()?.localized ?? "",
            network: viewModel.wallet?.networkType ?? .bitcoinSS,
            paymentHash: paymentHash,
            shareLogs: true,
            screenName: "EmptyLightningAccount")
        presentContactUsViewController(request: request)
    }
}

extension LTRecoverFundsViewController: AlertViewControllerDelegate {
    func onAlertOk() {
        self.navigationController?.popToRootViewController(animated: true)
    }
}

extension LTRecoverFundsViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return LTRecoverFundsSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch LTRecoverFundsSection(rawValue: section) {
        case .address:
            return 1
        case .amount:
            return 1
        case .fee:
            return 1
        case .summary:
            return 1
        case .error:
            return viewModel.error != nil ? 1 : 0
        case .none:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch LTRecoverFundsSection(rawValue: indexPath.section) {

        case .address:
            if let cell = tableView.dequeueReusableCell(withIdentifier: LTRecoverFundsAddressCell.identifier) as? LTRecoverFundsAddressCell {
                cell.configure(address: viewModel.address ?? "")
                cell.delegate = self
                cell.selectionStyle = .none
                return cell
            }
        case .amount:
            if let cell = tableView.dequeueReusableCell(withIdentifier: LTRecoverFundsAmountCell.identifier) as? LTRecoverFundsAmountCell {
                viewModel.amount = viewModel.type == .sendAll ? viewModel.maxReverseSwapAmount ?? 0 : viewModel.amount ?? 0
                cell.configure(amount: viewModel.amountText, isEditing: viewModel.type != .sendAll)
                cell.selectionStyle = .none
                return cell
            }
        case .fee:
            if let cell = tableView.dequeueReusableCell(withIdentifier: LTRecoverFundsFeeCell.identifier) as? LTRecoverFundsFeeCell {
                cell.configure(fee: viewModel.feeText, fiatFee: viewModel.feeFiatText, feeRate: viewModel.feeAmountRate ?? "", feeSliderIndex: viewModel.feeSlider, feeSliderMaxIndex: 3)
                cell.delegate = self
                cell.selectionStyle = .none
                return cell
            }
        case .summary:
            if let cell = tableView.dequeueReusableCell(withIdentifier: LTRecoverFundsSummaryCell.identifier) as? LTRecoverFundsSummaryCell {
                cell.configure(amount: viewModel.amountToBeRefundedText, fiat: viewModel.amountToBeRefundedFiatText)
                cell.selectionStyle = .none
                return cell
            }
        case .error:
            if let cell = tableView.dequeueReusableCell(withIdentifier: LTRecoverFundsErrorCell.identifier) as? LTRecoverFundsErrorCell {
                cell.configure(text: viewModel.error?.localized ?? "")
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch LTRecoverFundsSection(rawValue: section) {
        case .address:
            return UITableView.automaticDimension
        case .amount:
            return UITableView.automaticDimension
        case .fee:
            return UITableView.automaticDimension
        case .summary:
            return UITableView.automaticDimension
        case .error:
            return UITableView.automaticDimension
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch LTRecoverFundsSection(rawValue: section) {
        case .address:
            return headerView("id_receive".localized)
        case .amount:
            return headerView("id_amount".localized)
        case .fee:
            return headerView("id_network_fee".localized)
        case .summary:
            return headerView("Amount to be refounded".localized)
        case .error:
            return nil
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }

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

extension LTRecoverFundsViewController: LTRecoverFundsAddressCellDelegate {
    func didChange(address: String) {
        viewModel.address = address
        btnNextIsEnabled = !address.isEmpty
        prepare()
    }

    func qrcodeScanner() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogScanViewController") as? DialogScanViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.index = nil
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }
}

extension LTRecoverFundsViewController: DialogScanViewControllerDelegate {
    func didScan(value: ScanResult, index: Int?) {
        viewModel.address = value.result
        btnNextIsEnabled = !(value.result?.isEmpty ?? true)
        prepare()
    }
    func didStop() {
    }
}

extension LTRecoverFundsViewController: LTRecoverFundsFeeDelegate {
    func didChange(feeSliderIndex: Int) {
        viewModel.feeSlider = feeSliderIndex
        prepare()
    }
}

extension LTRecoverFundsViewController: SquareSliderViewDelegate {
    func sliderThumbIsMoving(_ sliderView: SquareSliderView) {
    }

    func sliderThumbDidStopMoving(_ position: Int) {
        if position == 1 {
            send()
        }
    }
}

extension LTRecoverFundsViewController: SendFailViewControllerDelegate {
    func onAgain() {
        send()
    }

    func onSupport(error: Error) {
        presentDialogErrorViewController(error: error, paymentHash: nil)
    }
}
