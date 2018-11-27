import Foundation
import UIKit
import PromiseKit

class ReceiveBtcViewController: KeyboardViewController {

    @IBOutlet weak var walletAddressLabel: UILabel!
    @IBOutlet weak var walletQRCode: UIImageView!
    @IBOutlet weak var amountTextfield: UITextField!
    @IBOutlet weak var estimateLabel: UILabel!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var fiatSwitchButton: UIButton!
    @IBOutlet weak var amountLabel: UILabel!

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
        updateQRCode()
        amountTextfield.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.white])

        amountTextfield.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        setButton()
        updateEstimate()
        let tap = UITapGestureRecognizer(target: self, action: #selector(zoomQR))
        walletQRCode.isUserInteractionEnabled = true
        walletQRCode.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(self.newAddress(_:)), name: NSNotification.Name(rawValue: "addressChanged"), object: nil)
        //receiveLabel.text = NSLocalizedString("id_receive", comment: "")
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
                    updateQRCode()
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let addressDetail = segue.destination as? AddressDetailViewController {
            addressDetail.wallet = wallet
            addressDetail.amount = amount_g
            addressDetail.providesPresentationContextTransitionStyle = true
            addressDetail.definesPresentationContext = true
            addressDetail.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
            addressDetail.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        }
    }

    @objc func zoomQR(recognizer: UITapGestureRecognizer) {
        self.performSegue(withIdentifier: "address", sender: self)
    }

    @IBAction func switchButtonClicked(_ sender: Any) {
        changeType()
    }

    func changeType() {
        let denomination = SettingsStore.shared.getDenominationSettings()
        var amount: String = amountTextfield.text!
        if (amount.isEmpty || Double(amount) == nil) {
            amount = "0"
        }
        if (selectedType == TransactionType.BTC) {
            selectedType = TransactionType.FIAT
            amountTextfield.text = String.toFiat(value: amount, fromType: denomination)
        } else {
            selectedType = TransactionType.BTC
            amountTextfield.text = String.toBtc(fiat: amount, toType: denomination)
        }
        setButton()
        updateEstimate()
    }

    func setButton() {
        if (selectedType == TransactionType.BTC) {
            fiatSwitchButton.setTitle(SettingsStore.shared.getDenominationSettings().rawValue, for: UIControlState.normal)
            fiatSwitchButton.backgroundColor = UIColor.customMatrixGreen()
            fiatSwitchButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        } else {
            fiatSwitchButton.setTitle(SettingsStore.shared.getCurrencyString(), for: UIControlState.normal)
            fiatSwitchButton.backgroundColor = UIColor.clear
            fiatSwitchButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        }
    }

    func updateEstimate() {
        let denomination = SettingsStore.shared.getDenominationSettings()
        var amount: String = amountTextfield.text!
        if (amount.isEmpty || Double(amount) == nil) {
            amount = "0"
        }
        if (selectedType == TransactionType.BTC) {
            let fiat = String.toFiat(value: amount, fromType: denomination)
            amount_g = Double(String.toBtc(value: amount, fromType: denomination, toType: DenominationType.BTC)!)!
            estimateLabel.text = "~" + String.formatFiat(fiat: fiat)
        } else {
            let amount: String = String.toBtc(fiat: amount, toType: DenominationType.BTC)!
            amount_g = Double(amount)!
            estimateLabel.text = "~" + String.formatBtc(value: amount, fromType: DenominationType.BTC, toType: denomination)
        }
        updateQRCode()
    }

    func updateQRCode() {
        if (amount_g == 0) {
            let uri = bip21Helper.btcURIforAddress(address: receiveAddress!)
            walletQRCode.image = QRImageGenerator.imageForTextDark(text: uri, frame: walletQRCode.frame)
        } else {
            walletQRCode.image = QRImageGenerator.imageForTextDark(text: bip21Helper.btcURIforAmount(address:self.receiveAddress!, amount: amount_g), frame: walletQRCode.frame)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        shareButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        updateEstimate()
    }

    @IBAction func shareButtonClicked(_ sender: Any) {
        var uri: String = receiveAddress!
        if (amount_g > 0) {
            uri = bip21Helper.btcURIforAmount(address:self.receiveAddress!, amount: amount_g)
        }
        let activityViewController = UIActivityViewController(activityItems: [uri] , applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        self.present(activityViewController, animated: true, completion: nil)
    }

    @IBAction func copyButtonClicked(_ sender: Any) {
        UIPasteboard.general.string = receiveAddress
    }

}

public enum TransactionType: UInt32 {
    case BTC = 0
    case FIAT = 1
}
