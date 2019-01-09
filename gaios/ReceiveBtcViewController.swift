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

    var wallet: WalletItem? = nil
    var selectedType = TransactionType.FIAT
    var amount_g: Double = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("id_receive", comment: "")
        self.tabBarController?.tabBar.isHidden = true
        amountTextfield.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.white])
        amountTextfield.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        let tap = UITapGestureRecognizer(target: self, action: #selector(copyToClipboard))
        walletQRCode.isUserInteractionEnabled = true
        walletQRCode.addGestureRecognizer(tap)
        amountLabel.text = NSLocalizedString("id_amount", comment: "")
        shareButton.setTitle(NSLocalizedString("id_share_address", comment: ""), for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(self.newAddress(_:)), name: NSNotification.Name(rawValue: EventType.AddressChanged.rawValue), object: nil)
        refresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.AddressChanged.rawValue), object: nil)
    }

    @IBAction func refreshClick(_ sender: Any) {
        let pointers: [UInt32] = [self.wallet!.pointer]
        changeAddresses(pointers).done { (wallets: [WalletItem]) in
            wallets.forEach { wallet in
                guard let address = wallet.receiveAddress else { return }
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: EventType.AddressChanged.rawValue), object: nil, userInfo: ["pointer": wallet.pointer, "address": address])
            }
        }.catch { _ in }
    }

    @objc func newAddress(_ notification: NSNotification) {
        guard let dict = notification.userInfo as NSDictionary? else { return }
        guard let pointer = dict["pointer"] as? UInt32 else { return }
        guard let address = dict["address"] as? String else { return }
        if wallet?.pointer == pointer {
            wallet?.receiveAddress = address
            DispatchQueue.main.async {
                self.refresh()
            }
        }
    }

    func refresh() {
        updateQRCode()
        setButton()
        updateEstimate()
    }

    @objc func copyToClipboard(_ sender: Any) {
        UIPasteboard.general.string = wallet!.getAddress()
    }

    @IBAction func switchButtonClicked(_ sender: Any) {
        guard let settings = getGAService().getSettings() else { return }
        let denomination = settings.denomination
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
        guard let settings = getGAService().getSettings() else { return }
        if (selectedType == TransactionType.BTC) {
            fiatSwitchButton.setTitle(settings.denomination.rawValue, for: UIControlState.normal)
            fiatSwitchButton.backgroundColor = UIColor.customMatrixGreen()
            fiatSwitchButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        } else {
            fiatSwitchButton.setTitle(settings.getCurrency(), for: UIControlState.normal)
            fiatSwitchButton.backgroundColor = UIColor.clear
            fiatSwitchButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        }
    }

    func updateEstimate() {
        guard let settings = getGAService().getSettings() else { return }
        let denomination = settings.denomination
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
        guard let wallet = self.wallet else {
            walletAddressLabel.isHidden = true
            walletQRCode.isHidden = true
            return
        }
        let bgq = DispatchQueue.global(qos: .background)
        Guarantee().compactMap(on: bgq) {
            return wallet.getAddress()
        }.done { address in
            let uri: String
            if (self.amount_g == 0) {
                uri = bip21Helper.btcURIforAddress(address: address)
                self.walletAddressLabel.text = address
            } else {
                uri = bip21Helper.btcURIforAmount(address: address, amount: self.amount_g)
                self.walletAddressLabel.text = uri
            }
            self.walletQRCode.image = QRImageGenerator.imageForTextWhite(text: uri, frame: self.walletQRCode.frame)
        }.catch{ _ in
            // Force to disconnect
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "autolock"), object: nil, userInfo: nil)
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
        guard let wallet = self.wallet else { return }
        let bgq = DispatchQueue.global(qos: .background)
        Guarantee().compactMap(on: bgq) {
            return wallet.getAddress()
        }.done { address in
            let uri = self.amount_g == 0 ? address : bip21Helper.btcURIforAmount(address: address, amount: self.amount_g)
            let activityViewController = UIActivityViewController(activityItems: [uri] , applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true, completion: nil)
        }.catch{ _ in }
    }
}

public enum TransactionType: UInt32 {
    case BTC = 0
    case FIAT = 1
}
