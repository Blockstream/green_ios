import Foundation
import PromiseKit
import UIKit
import AVFoundation
import NVActivityIndicatorView

class SendBtcViewController: KeyboardViewController, UITextFieldDelegate, NVActivityIndicatorViewable {

    @IBOutlet weak var textfield: UITextField!
    @IBOutlet weak var qrCodeReaderBackgroundView: QRCodeReaderView!
    @IBOutlet weak var bottomButton: UIButton!
    @IBOutlet weak var orLabel: UILabel!

    var uiErrorLabel: UIErrorLabel!
    var wallets = [WalletItem]()
    var wallet:WalletItem? = nil
    var transaction: Transaction? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("id_send_to", comment: "")
        orLabel.text = NSLocalizedString("id_or", comment: "")

        textfield.delegate = self
        textfield.attributedPlaceholder =
            NSAttributedString(string: NSLocalizedString("id_enter_an_address_or_private_key", comment: ""),
                attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        textfield.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: textfield.frame.height))
        textfield.leftViewMode = .always
        textfield.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        bottomButton.setTitle(NSLocalizedString("id_add_amount", comment: ""), for: .normal)
        uiErrorLabel = UIErrorLabel(self.view)

        qrCodeReaderBackgroundView.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateButton()
        qrCodeReaderBackgroundView.startScan()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        qrCodeReaderBackgroundView.stopScan()
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        updateButton()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        updateButton()
        return true
    }

    func updateButton() {
        if textfield?.text != "" {
            bottomButton.applyHorizontalGradient(colours: [UIColor.customMatrixGreenDark(), UIColor.customMatrixGreen()])
            bottomButton.isUserInteractionEnabled = true
        } else {
            bottomButton.applyHorizontalGradient(colours: [UIColor.customTitaniumMedium(), UIColor.customTitaniumLight()])
            bottomButton.isUserInteractionEnabled = false
        }
    }

    @IBAction func nextButtonClicked(_ sender: Any) {
        bottomButton.isUserInteractionEnabled = false
        createTransaction(userInput: textfield.text!)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBtcDetailsViewController {
            nextController.wallet = wallet
            nextController.transaction = transaction
        }
    }

    private func createSweepTransaction(userInput: String, feeRate: UInt64) -> Promise<Transaction> {
        let details: [String: Any] = ["private_key": userInput, "fee_rate":  feeRate]
        return gaios.createTransaction(details: details)
    }

    func createTransaction(userInput: String) {
        guard let settings = getGAService().getSettings() else { return }
        let feeRate: UInt64 = settings.customFeeRate ?? UInt64(1000)

        self.uiErrorLabel.isHidden = true
        startAnimating(type: NVActivityIndicatorType.ballRotateChase)

        createSweepTransaction(userInput: userInput, feeRate: feeRate).map { tx -> Promise<Transaction> in
            if tx.error.isEmpty {
                self.performSegue(withIdentifier: "next", sender: self)
            } else if tx.error != "id_invalid_private_key" {
                throw TransactionError.invalid(localizedDescription: NSLocalizedString(tx.error, comment: ""))
            }
            if self.transaction != nil {
                self.transaction!.addressees = [Addressee(address: userInput, satoshi: 0)]
                self.transaction!.feeRate = feeRate
                return gaios.createTransaction(transaction: self.transaction!)
            } else {
                let details: [String: Any] = ["addressees": [["address": userInput]], "fee_rate":  feeRate]
                return gaios.createTransaction(details: details)
            }
        }.then { tx in
            return tx
        }.compactMap { tx in
            self.transaction = tx
            if !tx.error.isEmpty && tx.error != "id_invalid_amount" && tx.error != "id_insufficient_funds" {
                throw TransactionError.invalid(localizedDescription: NSLocalizedString(tx.error, comment: ""))
            }
            self.performSegue(withIdentifier: "next", sender: self)
        }.catch { error in
            if let txError = (error as? TransactionError) {
                switch txError {
                case .invalid(let localizedDescription):
                    self.uiErrorLabel.text = localizedDescription
                }
            } else {
                self.uiErrorLabel.text = error.localizedDescription
            }
            self.uiErrorLabel.isHidden = false
            self.bottomButton.isUserInteractionEnabled = true
        }.finally {
            self.stopAnimating()
            if !self.uiErrorLabel.isHidden {
                self.qrCodeReaderBackgroundView.startScan()
            }
        }
    }
}

extension SendBtcViewController : QRCodeReaderDelegate {

    func onQRCodeReadSuccess(result: String) {
        qrCodeReaderBackgroundView.stopScan()
        createTransaction(userInput: result)
    }
}
