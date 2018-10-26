import Foundation
import UIKit
import PromiseKit

class ReceiveBtcViewController: UIViewController {

    @IBOutlet weak var walletAddressLabel: UILabel!
    @IBOutlet weak var walletQRCode: UIImageView!
    @IBOutlet weak var amountTextfield: UITextField!
    @IBOutlet weak var estimateLabel: UILabel!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var fiatSwitchButton: UIButton!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var receiveLabel: UILabel!

    var receiveAddress: String? = nil
    var wallet: WalletItem? = nil
    var selectedType = TransactionType.FIAT
    var amount_g: Double = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
        //walletAddressLabel.text = receiveAddress
        walletAddressLabel.text = wallet?.address
        receiveAddress = wallet?.address
        updateQRCode(amount: 0)
        amountTextfield.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.white])

        amountTextfield.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        self.hideKeyboardWhenTappedAround()
        setButton()
        updateType()
        updateEstimate()
        let tap = UITapGestureRecognizer(target: self, action: #selector(zoomQR))
        walletQRCode.isUserInteractionEnabled = true
        walletQRCode.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(self.newAddress(_:)), name: NSNotification.Name(rawValue: "addressChanged"), object: nil)
        receiveLabel.text = NSLocalizedString("id_receive", comment: "")
        amountLabel.text = NSLocalizedString("id_amount", comment: "")
        shareButton.setTitle(NSLocalizedString("id_share_address", comment: ""), for: .normal)
    }

    @objc func newAddress(_ notification: NSNotification) {
        print(notification.userInfo ?? "")
        if let dict = notification.userInfo as NSDictionary? {
            if let pointer = dict["pointer"] as? Int {
                if(pointer == Int(wallet!.pointer)) {
                    receiveAddress = wallet?.address
                    walletAddressLabel.text = wallet?.address
                    updateQRCode(amount: amount_g)
                }
            }
        }
    }

    @objc func zoomQR(recognizer: UITapGestureRecognizer) {
        let addressDetail = self.storyboard?.instantiateViewController(withIdentifier: "addressDetail") as! AddressDetailViewController
        addressDetail.wallet = wallet
        addressDetail.amount = amount_g
        addressDetail.providesPresentationContextTransitionStyle = true
        addressDetail.definesPresentationContext = true
        addressDetail.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        addressDetail.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        self.present(addressDetail, animated: true, completion: nil)
    }

    @IBAction func switchButtonClicked(_ sender: Any) {
        changeType()
    }

    func changeType() {
        if (selectedType == TransactionType.BTC) {
            selectedType = TransactionType.FIAT
        } else {
            selectedType = TransactionType.BTC
        }
        setButton()
        updateType()
        updateEstimate()
    }

    func setButton() {
        if (selectedType == TransactionType.BTC) {
            fiatSwitchButton.setTitle(SettingsStore.shared.getDenominationSettings(), for: UIControlState.normal)
            fiatSwitchButton.backgroundColor = UIColor.customMatrixGreen()
            fiatSwitchButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        } else {
            fiatSwitchButton.setTitle(SettingsStore.shared.getCurrencyString(), for: UIControlState.normal)
            fiatSwitchButton.backgroundColor = UIColor.clear
            fiatSwitchButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        }
    }

    func updateType() {
        if (selectedType == TransactionType.BTC) {
            typeLabel.text = SettingsStore.shared.getDenominationSettings()
        } else {
            typeLabel.text = SettingsStore.shared.getCurrencyString()
        }
    }

    func updateEstimate() {
        let amount: String = amountTextfield.text!

        guard let amount_double = Double(amount) else {
            if (selectedType == TransactionType.BTC) {
                estimateLabel.text = "~0.00 " + SettingsStore.shared.getCurrencyString()
            } else {
                estimateLabel.text = "~0.00 " + SettingsStore.shared.getDenominationSettings()
            }
            amount_g = 0
            updateQRCode(amount: 0)
            return
        }

        if (selectedType == TransactionType.BTC) {
            let denomination = SettingsStore.shared.getDenominationSettings()
            var amount_denominated: Double = 0
            if(denomination == SettingsStore.shared.denominationPrimary) {
                amount_denominated = amount_double
            } else if (denomination == SettingsStore.shared.denominationMilli) {
                amount_denominated = amount_double / 1000
            } else if (denomination == SettingsStore.shared.denominationMicro){
                amount_denominated = amount_double / 1000000
            }
            let converted = AccountStore.shared.btcToFiat(amount: amount_denominated)
            estimateLabel.text = String(format: "~%.2f %@", converted, SettingsStore.shared.getCurrencyString())
            amount_g = amount_denominated
            updateQRCode(amount: amount_denominated)
        } else {
            let converted = AccountStore.shared.fiatToBtc(amount: amount_double)
            amount_g = converted
            updateQRCode(amount: converted)
            estimateLabel.text = String(format: "~%f %@", converted, SettingsStore.shared.getDenominationSettings())
        }
    }

    func updateQRCode(amount: Double) {
        if (amount == 0) {
            let uri = bip21Helper.btcURIforAddress(address: receiveAddress!)
            walletQRCode.image = QRImageGenerator.imageForTextDark(text: uri, frame: walletQRCode.frame)
        } else {
            walletQRCode.image = QRImageGenerator.imageForTextDark(text: bip21Helper.btcURIforAmnount(address:self.receiveAddress!, amount: amount), frame: walletQRCode.frame)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        shareButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        let btc_amount: String = textField.text!
        updateEstimate()
    }

    @IBAction func shareButtonClicked(_ sender: Any) {
        let activityViewController = UIActivityViewController(activityItems: [receiveAddress!] , applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        self.present(activityViewController, animated: true, completion: nil)
    }

    @IBAction func copyButtonClicked(_ sender: Any) {
        UIPasteboard.general.string = receiveAddress
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        _ = navigationController?.popViewController(animated: true)
    }
}

public enum TransactionType: UInt32 {
    case BTC = 0
    case FIAT = 1
}
