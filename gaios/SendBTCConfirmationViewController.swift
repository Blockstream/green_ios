import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class SendBTCConfirmationViewController: KeyboardViewController, SlideButtonDelegate, NVActivityIndicatorViewable, UITextViewDelegate {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var slidingButton: SlidingButton!
    @IBOutlet weak var fiatAmountLabel: UILabel!
    @IBOutlet weak var walletNameLabel: UILabel!
    @IBOutlet weak var recepientAddressLabel: UILabel!
    @IBOutlet weak var sendingTitle: UILabel!
    @IBOutlet weak var fromTitle: UILabel!
    @IBOutlet weak var toTitle: UILabel!
    @IBOutlet weak var myNotesTitle: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!

    var uiErrorLabel: UIErrorLabel!
    var walletName: String = ""
    var wallet: WalletItem? = nil
    var transaction: Transaction!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
        walletNameLabel.text = transaction.isSweep ? "Paper Wallet" : wallet?.localizedName()
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
        let address = transaction.addressees.first!.address
        let satoshi = transaction.addressees.first!.satoshi
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
            transaction.memo = textView.text
        }
    }

    func completed(slidingButton: SlidingButton) {
        let bgq = DispatchQueue.global(qos: .background)

        firstly {
            let size = CGSize(width: 30, height: 30)
            uiErrorLabel.isHidden = true
            startAnimating(size, message: "Sending...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
            return Guarantee()
        }.then(on: bgq) {
            signTransaction(transaction: self.transaction)
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.compactMap(on: bgq) { result_dict in
            let result = result_dict["result"] as! [String: Any]
            if self.transaction.isSweep {
                _ = try getSession().broadcastTransaction(tx_hex: result["transaction"] as! String)
            } else {
                let call = try getSession().sendTransaction(details: result)
                // FIXME: 2FA
                _ = try call.resolve(self)
            }
        }.done { _ in
            self.executeOnDone()
        }.catch { error in
            self.stopAnimating()
            slidingButton.reset()
            self.uiErrorLabel.isHidden = false
            self.uiErrorLabel.text = NSLocalizedString(error.localizedDescription, comment: "")
        }
    }

    func executeOnDone() {
        self.startAnimating(CGSize(width: 30, height: 30), message: "Transaction Sent", messageFont: nil, type: NVActivityIndicatorType.blank)
        NVActivityIndicatorPresenter.sharedInstance.setMessage("Transaction Sent")
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.1) {
            self.stopAnimating()
            self.popBack(toControllerType: TransactionsController.self)
        }
    }

    override func keyboardWillShow(notification: NSNotification) {
        // Modified slightly for use in Green from the public release at "Managing the Keyboard" from Text Programming Guide for iOS
        super.keyboardWillShow(notification: notification)
        if let kbSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
            scrollView.contentInset = contentInsets;
            scrollView.scrollIndicatorInsets = contentInsets;
            var aRect = self.view.frame;
            aRect.size.height -= kbSize.height;
            if (!aRect.contains(textView.frame.origin) ) {
                scrollView.scrollRectToVisible(aRect, animated: true)
            }
        }
    }

    override func keyboardWillHide(notification: NSNotification) {
        super.keyboardWillHide(notification: notification)
        let contentInsets = UIEdgeInsets.zero;
        scrollView.contentInset = contentInsets;
        scrollView.scrollIndicatorInsets = contentInsets;
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
