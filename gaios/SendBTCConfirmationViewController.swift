import Foundation
import UIKit
import NVActivityIndicatorView

class SendBTCConfirmationViewController: UIViewController, SlideButtonDelegate, NVActivityIndicatorViewable, UITextViewDelegate{

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var slidingButton: SlidingButton!
    @IBOutlet weak var fiatAmountLabel: UILabel!
    @IBOutlet weak var walletNameLabel: UILabel!
    @IBOutlet weak var recepientAddressLabel: UILabel!
    @IBOutlet weak var sendingTitle: UILabel!
    @IBOutlet weak var fromTitle: UILabel!
    @IBOutlet weak var toTitle: UILabel!
    @IBOutlet weak var myNotesTitle: UILabel!

    var toAddress: String = ""
    var fiat_amount: Double = 0
    var fiatFeeAmount: Double = 0
    var btc_amount: Double = 0
    var satoshi_amount: Int = 0
    var satoshi_fee: Int = 0
    var walletName: String = ""
    var wallet: WalletItem? = nil
    var payload: [String : Any]? = nil
    var selectedType: TransactionType? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        walletNameLabel.text = walletName
        recepientAddressLabel.text = toAddress
        fiatFeeAmount = AccountStore.shared.satoshiToUSD(amount: UInt64(satoshi_fee * 250))
        self.tabBarController?.tabBar.isHidden = true
        walletNameLabel.text = wallet?.name
        hideKeyboardWhenTappedAround()
        slidingButton.delegate = self
        updateAmountLabel()
        textView.delegate = self
        textView.text = "Add a note..."
        textView.textColor = UIColor.customTitaniumLight()
        sendingTitle.text = NSLocalizedString("psending", comment: "")
        fromTitle.text = NSLocalizedString("pfrom", comment: "")
        toTitle.text = NSLocalizedString("pto", comment: "")
        myNotesTitle.text = NSLocalizedString("pmy_notes", comment: "")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.textColor = UIColor.customTitaniumLight()
    }

    func updateAmountLabel() {
        if (selectedType == TransactionType.BTC) {
            fiatAmountLabel.text = String(format: "%f BTC (%f USD)", btc_amount, fiat_amount)
        } else if (selectedType == TransactionType.FIAT) {
            fiatAmountLabel.text = String(format: "%f USD (%f BTC)", fiat_amount, btc_amount)
        }
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
        }
    }

    func completed(slidingButton: SlidingButton) {
        print("send now!")
        let size = CGSize(width: 30, height: 30)
        startAnimating(size, message: "Sending...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
        DispatchQueue.global(qos: .background).async {
            wrap {try getSession().sendTransaction(details: self.payload!)
                }.done { (result: TwoFactorCall?) in
                    do {
                        let status = try result?.getStatus()
                        let parsed = status!["status"] as! String
                        if(parsed == "request_code") {
                            //request code
                            let methods = status!["methods"] as! NSArray
                            if(methods.count > 1) {
                                self.stopAnimating()
                                self.performSegue(withIdentifier: "twoFactorSelector", sender: result)
                            } else {
                                let method = methods[0] as! String
                                let req = try result?.requestCode(method: method)
                                let status1 = try result?.getStatus()
                                let parsed1 = status1!["status"] as! String
                                if(parsed1 == "resolve_code") {
                                    self.stopAnimating()
                                    self.performSegue(withIdentifier: "twoFactor", sender: result)
                                }
                            }

                        } else if (parsed == "call") {
                            let json = try result?.call()
                            self.startAnimating(CGSize(width: 30, height: 30), message: "Transaction Sent", messageFont: nil, type: NVActivityIndicatorType.blank)
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.1) {
                                self.stopAnimating()
                                self.navigationController?.popToRootViewController(animated: true)
                            }
                        }
                    } catch {
                        self.stopAnimating()
                        print("couldn't call")
                    }
                } .catch { error in
                    self.stopAnimating()
                    print(error)
                    print("wtf")
            }
        }
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
