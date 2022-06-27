import Foundation
import UIKit
import PromiseKit

class DialogSendHWSummaryViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var icArrow: UIImageView!
    @IBOutlet weak var icWallet: UIImageView!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblRecipientTitle: UILabel!
    @IBOutlet weak var lblRecipientAddress: UILabel!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblDenomination: UILabel!
    @IBOutlet weak var lblAmount: UILabel!
    @IBOutlet weak var lblFiat: UILabel!

    @IBOutlet weak var lblFeeTitle: UILabel!
    @IBOutlet weak var lblFeeAmount: UILabel!
    @IBOutlet weak var lblFeeFiat: UILabel!
    @IBOutlet weak var lblFeeInfo: UILabel!

    @IBOutlet weak var lblChangeTitle: UILabel!
    @IBOutlet weak var lblChangeHint: UILabel!

    private var btc: String {
        return AccountsManager.shared.current?.gdkNetwork?.getFeeAsset() ?? ""
    }

    var network: String? {
        get {
            return AccountsManager.shared.current?.network
        }
    }

    var transaction: Transaction?

    var isLedger = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        view.alpha = 0.0

        if isLedger {
            icWallet.image = UIImage(named: "ic_hww_ledger")
        } else {
            icWallet.image = UIImage(named: "ic_hww_jade")
        }

        AnalyticsManager.shared.recordView(.verifyAddress, sgmt: AnalyticsManager.shared.sessSgmt(AccountsManager.shared.current))
    }

    func setContent() {
        lblTitle.text = NSLocalizedString("id_confirm_on_your_device", comment: "")
        icArrow.image = UIImage(named: "ic_hww_arrow")!.maskWithColor(color: UIColor.customMatrixGreen())

        if let transaction = transaction, let addressee = transaction.addressees.first {

            lblRecipientTitle.text = NSLocalizedString("id_recipient", comment: "")
            lblRecipientAddress.text = addressee.address

            let addreessee = transaction.addressees.first
            var value = addreessee?.satoshi ?? 0
            let network = AccountsManager.shared.current?.gdkNetwork
            let asset = (network?.liquid ?? false) ? addreessee?.assetId ?? "" : "btc"
            if !(AccountsManager.shared.current?.isSingleSig ?? false) && transaction.sendAll {
                value = transaction.amounts.filter({$0.key == asset}).first?.value ?? 0
            }
            if asset == "btc" || asset == getGdkNetwork("liquid").policyAsset {
                if let balance = Balance.convert(details: ["satoshi": value]) {
                    let (value, denom) = value == 0 ? ("", "") : balance.get(tag: btc)
                    lblAmount.text = value ?? ""
                    lblDenomination.text = "\(denom)"
                    let (fiat, fiatCurrency) = balance.get(tag: "fiat")
                    lblFiat.text = "≈ \(fiat ?? "N.A.") \(fiatCurrency)"
                }
            } else {
                let info = SessionsManager.current?.registry?.infos[asset] ?? AssetInfo(assetId: asset, name: "", precision: 0, ticker: "")
                if let assetInfo = info.encode() {
                    let details = ["satoshi": value, "asset_info": assetInfo] as [String: Any]
                    if let balance = Balance.convert(details: details) {
                        let (amount, ticker) = value == 0 ? ("", "") : balance.get(tag: asset)
                        lblAmount.text = amount ?? "N.A."
                        lblDenomination.text = "\(ticker)"
                        lblFiat.isHidden = true
                    }
                }
            }
            icon.image = UIImage(named: "default_asset_icon")!
            if AccountsManager.shared.current?.network == "mainnet" {
                icon.image = UIImage(named: "ntw_btc")
            } else if AccountsManager.shared.current?.network == "testnet" {
                icon.image = UIImage(named: "ntw_testnet")
            } else {
                icon.image = SessionsManager.current?.registry?.image(for: asset)
            }
            lblFeeTitle.text = NSLocalizedString("id_fee", comment: "")
            if let balance = Balance.convert(details: ["satoshi": transaction.fee]) {
                let (amount, denom) = balance.get(tag: btc)
                lblFeeAmount.text = "\(amount ?? "") \(denom)"
                let (fiat, fiatCurrency) = balance.get(tag: "fiat")
                lblFeeFiat.text = "≈ \(fiat ?? "N.A.") \(fiatCurrency)"
                lblFeeInfo.text = "\(String(format: "( %.2f satoshi / vbyte )", Double(transaction.feeRate) / 1000))"
            }
            lblChangeTitle.isHidden = true
            lblChangeHint.isHidden = true
            if isLedger {
                handleChange(transaction)
            }
        }
    }

    func handleChange(_ transaction: Transaction) {
        if let outputs = transaction.transactionOutputs, !outputs.isEmpty {
            var changeAddress = [String]()
            outputs.forEach { output in
                let isChange = output["is_change"] as? Bool ?? false
                let isFee = output["is_fee"] as? Bool ?? false
                if isChange && !isFee, let address = output["address"] as? String {
                    changeAddress.append(address)
                }
            }
            if !changeAddress.isEmpty {
                lblChangeTitle.text = NSLocalizedString("id_change", comment: "")
                lblChangeHint.text = changeAddress.map { "\($0)"}.joined(separator: "\n")
                lblChangeTitle.isHidden = false
                lblChangeHint.isHidden = false
            }
        }
    }

    func setStyle() {
        cardView.layer.cornerRadius = 20
        cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bg.cornerRadius = 8.0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func dismiss() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }

    @IBAction func btnDismiss(_ sender: Any) {
        dismiss()
    }
}