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

    var uiErrorLabel: UIErrorLabel!
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
        uiErrorLabel = UIErrorLabel(self.view)
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
        recepientAddressLabel.text = address
        let btcAmount = String.formatBtc(satoshi: satoshi)
        let fiatAmount = String.formatFiat(satoshi: satoshi)
        fiatAmountLabel.text = String(format: "%@ ( %@ )", btcAmount, fiatAmount)
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
        uiErrorLabel.isHidden = true
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
            self.popBack(toControllerType: TransactionsController.self)
        }
    }

    func onDone(_ sender: TwoFactorCallHelper?) {
        executeOnDone()
    }

    func onError(_ sender: TwoFactorCallHelper?, text: String) {
        self.stopAnimating()
        slidingButton.reset()
        uiErrorLabel.isHidden = false
        uiErrorLabel.text = NSLocalizedString(text, comment: "")
    }

    /// pop back to specific viewcontroller
    func popBack<T: UIViewController>(toControllerType: T.Type) {
        if var viewControllers: [UIViewController] = self.navigationController?.viewControllers {
            viewControllers = viewControllers.reversed()
            for currentViewController in viewControllers {
                if currentViewController .isKind(of: toControllerType) {
                    self.navigationController?.popToViewController(currentViewController, animated: true)
                    break
                }
            }
        }
    }
}
