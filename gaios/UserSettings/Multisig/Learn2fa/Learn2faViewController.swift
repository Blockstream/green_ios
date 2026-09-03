import Foundation
import UIKit
import core

protocol Learn2faViewControllerDelegate: AnyObject {
    func userLogout()
}

class Learn2faViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!

    @IBOutlet weak var lblResetTitle: UILabel!
    @IBOutlet weak var lblResetHint: UILabel!
    @IBOutlet weak var lblHowtoTitle: UILabel!
    @IBOutlet weak var lblHowtoHint: UILabel!
    @IBOutlet weak var btnCancelReset: UIButton!
    @IBOutlet weak var lblPermanentTitle: UILabel!
    @IBOutlet weak var lblPermanentHint: UILabel!
    @IBOutlet weak var btnUndoReset: UIButton!

    private let viewModel: Learn2faViewModel
    weak var delegate: Learn2faViewControllerDelegate?
    weak var coordinator: SettingsCoordinator?

    init?(coder: NSCoder, viewModel: Learn2faViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()

        AnalyticsManager.shared.recordView(.twoFactorReset, sgmt: AnalyticsManager.shared.sessSgmt(WalletsStorage.shared.current))
    }

    func setContent() {
        title = ""
        if viewModel.twofactorReset?.isDisputeActive ?? false {
            lblTitle.text = "id_2fa_dispute_in_progress".localized
            lblResetTitle.text = "id_your_wallet_is_locked_under_2fa".localized
            lblResetHint.text = "id_the_1_year_2fa_reset_process".localized
            lblHowtoTitle.text = "id_how_to_stop_this_reset".localized
            lblHowtoHint.text = "id_if_you_are_the_rightful_owner".localized
            btnCancelReset.setTitle("id_cancel_2fa_reset".localized, for: .normal)
            lblPermanentTitle.text = "id_undo_2fa_dispute".localized
            lblPermanentHint.text = "id_if_you_initiated_the_2fa_reset".localized
            // when in dispute, use the button to undo a dispute
            btnUndoReset.setTitle("id_undo_2fa_dispute".localized, for: .normal)
            return
        }
        let resetDaysRemaining = viewModel.twofactorReset?.daysRemaining
        lblTitle.text = "id_2fa_reset_in_progress".localized
        lblResetTitle.text = String(format: "id_your_wallet_is_locked_for_a".localized, resetDaysRemaining ?? 0)
        lblResetHint.text = "id_the_waiting_period_is_necessary".localized
        lblHowtoTitle.text = "id_how_to_stop_this_reset".localized
        lblHowtoHint.text = String(format: "id_if_you_have_access_to_a".localized, resetDaysRemaining ?? 0)
        btnCancelReset.setTitle("id_cancel_2fa_reset".localized, for: .normal)
        lblPermanentTitle.text = "id_permanently_block_this_wallet".localized
        lblPermanentHint.text = "id_if_you_did_not_request_the".localized
        // when not in dispute, use the button to dispute
        btnUndoReset.setTitle("id_dispute_twofactor_reset".localized, for: .normal)
        btnUndoReset?.titleLabel?.lineBreakMode = NSLineBreakMode.byWordWrapping
        btnUndoReset?.titleLabel?.textAlignment = .center
    }

    func canceltwoFactorReset() {
        Task { [weak self] in
            do {
                self?.startAnimating()
                try await self?.viewModel.backend?.cancelTwoFactorReset()
                self?.stopAnimating()
                await MainActor.run {
                    DropAlert().success(message: "Reset Cancelled")
                    if let coordinator = self?.coordinator {
                        coordinator.didCancelTwoFactorReset()
                    } else {
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            } catch {
                self?.stopAnimating()
                self?.showAlert(title: "id_error".localized, message: "id_cancel_twofactor_reset".localized)
            }
        }
    }

    func disputeReset(email: String) {
        Task { [weak self] in
            do {
                self?.startAnimating()
                try await self?.viewModel.backend?.resetTwoFactor(email: email, isDispute: true)
                self?.stopAnimating()
                await MainActor.run {
                    DropAlert().success(message: "Reset Disputed")
                    if let coordinator = self?.coordinator {
                        coordinator.navigate(to: .logout)
                    } else {
                        self?.delegate?.userLogout()
                    }
                }
            } catch {
                self?.stopAnimating()
                self?.showAlert(title: "id_error".localized, message: "id_dispute_twofactor_reset".localized)
            }
        }
    }

    func undoReset(email: String) {
        Task { [weak self] in
            do {
                self?.startAnimating()
                try await self?.viewModel.backend?.undoTwoFactorReset(email: email)
                self?.stopAnimating()
                await MainActor.run {
                    DropAlert().success(message: "Reset Undone")
                    if let coordinator = self?.coordinator {
                        coordinator.navigate(to: .logout)
                    } else {
                        self?.delegate?.userLogout()
                    }
                }
            } catch {
                self?.stopAnimating()
                self?.showAlert(title: "id_error".localized, message: "id_undo_2fa_dispute".localized)
            }
        }
    }

    @IBAction func BtnCancelReset(_ sender: Any) {
        canceltwoFactorReset()
    }

    @IBAction func BtnUndoReset(_ sender: Any) {
        let isDisputeActive = viewModel.twofactorReset?.isDisputeActive ?? false
        let alertTitle = isDisputeActive ? "id_undo_2fa_dispute".localized : "id_dispute_twofactor_reset".localized
        let alertMsg = isDisputeActive ? "id_provide_the_email_you".localized : ""
        let alert = UIAlertController(title: alertTitle, message: alertMsg, preferredStyle: .alert)
        alert.addTextField { (textField) in textField.placeholder = "id_email".localized }
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel) { _ in })
        alert.addAction(UIAlertAction(title: "id_next".localized, style: .default) { _ in
            let email = alert.textFields![0].text!
            if isDisputeActive {
                self.undoReset(email: email)
            } else {
                self.disputeReset(email: email)
            }
        })
        self.present(alert, animated: true, completion: nil)
    }
}
