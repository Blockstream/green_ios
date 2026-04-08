import Foundation
import UIKit
import gdk
import greenaddress
import core

enum LTRedeemSection: Int, CaseIterable {
    case address
    case amount
    case error
}

class LTRedeemViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var squareSliderView: SquareSliderView!
    private var headerH: CGFloat = 36.0
    var viewModel: LTRedeemViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
    }

    func setContent() {
        title = "id_sweep".localized
        squareSliderView.delegate = self
    }

    func setStyle() {
        view.backgroundColor = UIColor.gBlackBg()
    }

    func send() {
        startAnimating()
        Task { [weak self] in
            do {
                try await self?.viewModel.redeem()
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
            vc.viewModel = AlertViewModel(
                title: "Node Onchain Balance".localized,
                hint: "id_your_transaction_was".localized)
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
    @MainActor
    func presentDialogErrorViewController(error: Error, paymentHash: String?) {
        let request = ZendeskErrorRequest(
            error: error.description().localized,
            network: viewModel.wallet?.networkType ?? .bitcoinSS,
            paymentHash: paymentHash,
            shareLogs: true,
            screenName: "EmptyLightningAccount")
        presentContactUsViewController(request: request)
    }
}

extension LTRedeemViewController: AlertViewControllerDelegate {
    func onAlertOk() {
        self.navigationController?.popToRootViewController(animated: true)
    }
}

extension LTRedeemViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return LTRedeemSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch LTRedeemSection(rawValue: section) {
        case .address:
            return 1
        case .amount:
            return 1
        case .error:
            return viewModel.error != nil ? 1 : 0
        case .none:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch LTRedeemSection(rawValue: indexPath.section) {

        case .address:
            if let cell = tableView.dequeueReusableCell(withIdentifier: LTRecoverFundsAddressCell.identifier) as? LTRecoverFundsAddressCell {
                cell.configure(address: viewModel.onChainAddress ?? "")
                cell.delegate = self
                cell.selectionStyle = .none
                return cell
            }
        case .amount:
            if let cell = tableView.dequeueReusableCell(withIdentifier: LTRecoverFundsAmountCell.identifier) as? LTRecoverFundsAmountCell {
                cell.configure(amount: viewModel.amountText, isEditing: false)
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
        switch LTRedeemSection(rawValue: section) {
        case .address:
            return UITableView.automaticDimension
        case .amount:
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
        switch LTRedeemSection(rawValue: section) {
        case .address:
            return headerView("id_address".localized)
        case .amount:
            return headerView("id_amount".localized)
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

extension LTRedeemViewController: LTRecoverFundsAddressCellDelegate {
    func didChange(address: String) {
        viewModel.onChainAddress = address
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

extension LTRedeemViewController: DialogScanViewControllerDelegate {
    func didScan(value: ScanResult, index: Int?) {
        viewModel.onChainAddress = value.result
    }
    func didStop() {
    }
}

extension LTRedeemViewController: SquareSliderViewDelegate {
    func sliderThumbIsMoving(_ sliderView: SquareSliderView) {
    }

    func sliderThumbDidStopMoving(_ position: Int) {
        if position == 1 {
            send()
        }
    }
}

extension LTRedeemViewController: SendFailViewControllerDelegate {
    func onAgain() {
        send()
    }

    func onSupport(error: Error) {
        presentDialogErrorViewController(error: error, paymentHash: nil)
    }
}
