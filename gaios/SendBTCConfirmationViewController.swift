import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class SendBTCConfirmationViewController: KeyboardViewController, SlideButtonDelegate, NVActivityIndicatorViewable, UITextViewDelegate {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var slidingButton: SlidingButton!
    @IBOutlet weak var feeLabel: UILabel!
    @IBOutlet weak var walletLabel: UILabel!
    @IBOutlet weak var walletView: UIView!
    @IBOutlet weak var recepientAddressLabel: UILabel!
    @IBOutlet weak var sendingTitle: UILabel!
    @IBOutlet weak var fromTitle: UILabel!
    @IBOutlet weak var toTitle: UILabel!
    @IBOutlet weak var myNotesTitle: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var feeTitle: UILabel!
    @IBOutlet weak var amountText: UITextField!
    @IBOutlet weak var currencyButton: UIButton!

    var uiErrorLabel: UIErrorLabel!
    var wallet: WalletItem? = nil
    var transaction: Transaction!
    var isFiat = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        self.title = NSLocalizedString("id_send", comment: "")
        walletLabel.text = transaction.isSweep ?  NSLocalizedString("id_sweep_from_paper_wallet", comment: "") : wallet?.localizedName()
        slidingButton.delegate = self
        slidingButton.buttonText = NSLocalizedString("id_slide_to_send", comment: "")
        uiErrorLabel = UIErrorLabel(self.view)
        textView.delegate = self
        textView.text = NSLocalizedString("id_add_a_note", comment: "")
        textView.textColor = UIColor.customTitaniumLight()
        sendingTitle.text = NSLocalizedString("id_sending", comment: "")
        fromTitle.text = NSLocalizedString("id_from", comment: "")
        toTitle.text = NSLocalizedString("id_to", comment: "")
        myNotesTitle.text = NSLocalizedString("id_my_notes", comment: "")
        //feeTitle.text = NSLocalizedString("id_total_with_fee", comment: "")
        setupCurrencyButton()
        update()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        walletView.applyCardGradient()
    }

    func update() {
        let address = transaction.addressees.first!.address
        let satoshi = transaction.addressees.first!.satoshi
        recepientAddressLabel.text = address
        if isFiat {
            amountText.text = String.toFiat(satoshi: satoshi).split(separator: " ").map(String.init).first
            feeLabel.text = String.toFiat(satoshi: transaction.fee)
        } else {
            amountText.text = String.toBtc(satoshi: satoshi).split(separator: " ").map(String.init).first
            feeLabel.text = String.toBtc(satoshi: transaction.fee)
        }
    }

    func setupCurrencyButton() {
        guard let settings = getGAService().getSettings() else { return }
        if !isFiat {
            currencyButton.setTitle(settings.denomination.toString(), for: UIControlState.normal)
            currencyButton.backgroundColor = UIColor.customMatrixGreen()
        } else {
            currencyButton.setTitle(settings.getCurrency(), for: UIControlState.normal)
            currencyButton.backgroundColor = UIColor.clear
        }
        currencyButton.setTitleColor(UIColor.white, for: UIControlState.normal)
    }

    @IBAction func switchCurrency(_ sender: Any) {
        isFiat = !isFiat
        update()
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
            textView.text = NSLocalizedString("id_add_a_note", comment: "")
            textView.textColor = UIColor.customTitaniumLight()
        } else {
            transaction.memo = textView.text
        }
    }

    func completed(slidingButton: SlidingButton) {
        let bgq = DispatchQueue.global(qos: .background)

        firstly {
            uiErrorLabel.isHidden = true
            self.startAnimating()
            return Guarantee()
        }.then(on: bgq) {
            signTransaction(transaction: self.transaction)
        }.then(on: bgq) { call in
            call.resolve(self)
        }.compactMap(on: bgq) { result_dict in
            let result = result_dict["result"] as! [String: Any]
            if self.transaction.isSweep {
                _ = try getSession().broadcastTransaction(tx_hex: result["transaction"] as! String)
                return nil
            } else {
                return try getSession().sendTransaction(details: result)
            }
        }.then(on: bgq) { (call: TwoFactorCall?) in
            call!.resolve(self)
        }.done { _ in
            self.executeOnDone()
        }.catch { error in
            self.stopAnimating()
            self.slidingButton.reset()
            self.uiErrorLabel.isHidden = false
            if let twofaError = error as? TwoFactorCallError {
                switch twofaError {
                case .failure(let localizedDescription), .cancel(let localizedDescription):
                    self.uiErrorLabel.text = localizedDescription
                }
            } else {
                self.uiErrorLabel.text = error.localizedDescription
            }
        }
    }

    func executeOnDone() {
        self.startAnimating(message: NSLocalizedString("id_transaction_sent", comment: ""))
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
