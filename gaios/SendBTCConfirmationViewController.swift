import Foundation
import UIKit
import NVActivityIndicatorView

class SendBTCConfirmationViewController: UIViewController, SlideButtonDelegate, NVActivityIndicatorViewable, UITextViewDelegate, TwoFactorCallDelegate {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var slidingButton: SlidingButton!
    @IBOutlet weak var fiatAmountLabel: UILabel!
    @IBOutlet weak var walletNameLabel: UILabel!
    @IBOutlet weak var recepientAddressLabel: UILabel!
    @IBOutlet weak var sendingTitle: UILabel!
    @IBOutlet weak var fromTitle: UILabel!
    @IBOutlet weak var toTitle: UILabel!
    @IBOutlet weak var myNotesTitle: UILabel!

    var walletName: String = ""
    var wallet: WalletItem? = nil
    var selectedType: TransactionType? = nil
    var transaction: TransactionHelper?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
        walletNameLabel.text = (transaction?.data["is_sweep"] as! Bool) ? "Paper Wallet" : wallet?.name
        hideKeyboardWhenTappedAround()
        slidingButton.delegate = self
        refresh()
        textView.delegate = self
        textView.text = "Add a note..."
        textView.textColor = UIColor.customTitaniumLight()
        sendingTitle.text = NSLocalizedString("id_sending", comment: "")
        fromTitle.text = NSLocalizedString("id_from", comment: "")
        toTitle.text = NSLocalizedString("id_to", comment: "")
        myNotesTitle.text = NSLocalizedString("id_my_notes", comment: "")
    }

    func refresh() {
        let addressees = transaction?.addresses()
        let address = addressees![0]["address"] as! String
        let satoshi = transaction?.data["satoshi"] as! UInt64
        let btcAmount = Double(satoshi) / 100000000
        recepientAddressLabel.text = address
        if (selectedType == TransactionType.BTC) {
            fiatAmountLabel.text = String(format: "%f BTC (%f USD)", btcAmount, 0)
        } else if (selectedType == TransactionType.FIAT) {
            fiatAmountLabel.text = String(format: "%f USD (%f BTC)", 0, btcAmount)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.textColor = UIColor.customTitaniumLight()
    }


    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.customTitaniumLight() {
            textView.text = nil
            textView.textColor = UIColor.white
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Add a note..."
            textView.textColor = UIColor.customTitaniumLight()
        } else {
            transaction?.data["memo"] = textView.text
        }
    }

    func completed(slidingButton: SlidingButton) {
        print("send now!")
        let size = CGSize(width: 30, height: 30)
        startAnimating(size, message: "Sending...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
        if self.transaction?.data["is_sweep"] as! Bool {
            DispatchQueue.global(qos: .background).async {
                wrap {
                    let tx = try getSession().signTransaction(details: self.transaction!.data)!
                    _ = try getSession().broadcastTransaction(tx_hex: tx["transaction"] as! String)
                }.done {
                    self.executeOnDone()
                } .catch { error in
                    DispatchQueue.main.async {
                        self.onError(nil, text: error.localizedDescription)
                    }
                }
            }
        }
        else {
            DispatchQueue.global(qos: .background).async {
                wrap {
                    try getSession().sendTransaction(details: (self.transaction?.data)!)
                }.done { (result: TwoFactorCall) in
                    try TwoFactorCallHelper(result, delegate: self).resolve()
                } .catch { error in
                    DispatchQueue.main.async {
                        self.onError(nil, text: error.localizedDescription)
                    }
                }
            }
        }
    }

    func onResolve(_ sender: TwoFactorCallHelper?) {
        let alert = TwoFactorCallHelper.CodePopup(sender!)
        self.present(alert, animated: true, completion: nil)
    }

    func onRequest(_ sender: TwoFactorCallHelper?) {
        let alert = TwoFactorCallHelper.MethodPopup(sender!)
        self.present(alert, animated: true, completion: nil)
    }

    func executeOnDone() {
        self.startAnimating(CGSize(width: 30, height: 30), message: "Transaction Sent", messageFont: nil, type: NVActivityIndicatorType.blank)
        NVActivityIndicatorPresenter.sharedInstance.setMessage("Transaction Sent")
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.1) {
            self.stopAnimating()
            self.navigationController?.popToRootViewController(animated: true)
        }
    }

    func onDone(_ sender: TwoFactorCallHelper?) {
        executeOnDone()
    }

    func onError(_ sender: TwoFactorCallHelper?, text: String) {
        self.stopAnimating()
        slidingButton.reset()
        print(text)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? VerifyTwoFactorViewController {
            nextController.twoFactor = sender as? TwoFactorCall
        }
        if let nextController = segue.destination as? TwoFactorSlectorViewController {
            nextController.twoFactor = sender as? TwoFactorCall
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
}
