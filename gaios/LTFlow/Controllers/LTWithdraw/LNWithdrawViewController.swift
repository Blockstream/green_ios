import Foundation
import UIKit
import BreezSDK
import greenaddress
import lightning
import core

class LTWithdrawViewController: KeyboardViewController {

    var requestData: LnUrlWithdrawRequestData?
    var session: LightningSessionManager? { WalletManager.current?.lightningSession }

    enum LTWithdrawSection: Int, CaseIterable {
        case amount
        case note
    }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var squareSliderView: SquareSliderView!
    private var headerH: CGFloat = 36.0

    var amount: UInt64?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "id_withdraw".localized
        lblTitle.text = String(format: "id_you_are_redeeming_funds_from_s".localized, "\n\(requestData?.domain ?? "")")
        btnNext.setTitle("id_withdraw".localized, for: .normal)
        squareSliderView.delegate = self
    }

    override func keyboardWillHide(notification: Notification) {
        if keyboardDismissGesture != nil {
            view.removeGestureRecognizer(keyboardDismissGesture!)
            keyboardDismissGesture = nil
        }
        tableView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        squareSliderView.slideStr = "Slide to redeem".localized
        squareSliderView.reset()
        squareSliderView.isActive(amount != nil)
        for cell in tableView.visibleCells {
            if let c = cell as? LTWithdrawAmountCell {
                c.responderOn()
            }
        }
    }

    func onChange(_ amount: UInt64?) {
        self.amount = amount
        btnNext.setStyle(amount == nil ? .primaryDisabled : .primary)

        squareSliderView.isActive(amount != nil)
    }

    @MainActor
    func presentAlertSuccess() {

        let viewModel = AlertViewModel(title: "id_success".localized,
                                       hint: String(format: "id_s_will_send_you_the_funds_it".localized, requestData?.domain ?? ""))
        let storyboard = UIStoryboard(name: "Alert", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AlertViewController") as? AlertViewController {
            vc.viewModel = viewModel
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }

    func next() {
        let description = lblTitle.text
        guard let requestData = requestData else { return }
        guard let amount = self.amount else { return }
        startLoader()
        Task {
            do {
                let lightBridge = WalletManager.current?.lightningSession?.lightBridge
                let res = try lightBridge?.withdrawLnurl(requestData: requestData, amount: amount, description: description)
                stopLoader()
                squareSliderView.reset()
                switch res {
                case .ok:
                    presentAlertSuccess()
                case .errorStatus(let data):
                    DropAlert().error(message: data.reason)
                case .timeout(let data):
                    DropAlert().error(message: "Timeout".localized)
                case .none:
                    DropAlert().error(message: "id_operation_failure".localized)
                }
            } catch {
                stopLoader()
                squareSliderView.reset()
                switch error {
                case BreezSDK.SdkError.Generic(let msg):
                    // BreezSDK.SdkError.ServiceConnectivity(let msg):
                    DropAlert().error(message: msg.localized)
                default:
                    DropAlert().error(message: "id_operation_failure".localized)
                }
            }
        }
    }

    @IBAction func tapNext(_ sender: Any) {
        next()
    }
}

extension LTWithdrawViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return LTWithdrawSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch LTWithdrawSection(rawValue: indexPath.section) {
        case .amount:
            if let cell = tableView.dequeueReusableCell(withIdentifier: LTWithdrawAmountCell.identifier) as? LTWithdrawAmountCell {
                cell.configure(maxAmount: requestData?.maxWithdrawableSatoshi ?? 0,
                onChange: { [weak self] amount in
                    self?.onChange(amount)
                })
                cell.selectionStyle = .none
                return cell
            }
        case .note:
            if let cell = tableView.dequeueReusableCell(withIdentifier: LTWithdrawNoteCell.identifier) as? LTWithdrawNoteCell {
                cell.configure(text: requestData?.defaultDescription ?? "")
                cell.selectionStyle = .none
                return cell
            }

        default:
            break
        }

        return UITableViewCell()
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch LTWithdrawSection(rawValue: section) {
        case .amount:
            return headerView("id_amount_to_receive".localized)
        case .note:
            return headerView("id_description".localized)
        case .none:
            return nil
        }
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

extension LTWithdrawViewController: AlertViewControllerDelegate {
    @MainActor
    func onAlertOk() {
        navigationController?.popToRootViewController(animated: true)
    }
}

extension LTWithdrawViewController: SquareSliderViewDelegate {
    func sliderThumbIsMoving(_ sliderView: SquareSliderView) {
        //
    }

    func sliderThumbDidStopMoving(_ position: Int) {
        if position == 1 {
            next()
        }
    }
}
