import Foundation
import UIKit
import core
import gdk

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

    var transaction: Transaction?
    var account: WalletItem!
    var isLedger = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        view.alpha = 0.0

        if isLedger {
            icWallet.image = UIImage(named: "ic_hww_ledger")
        } else {
            let isV2 = BleViewModel.shared.jade?.version?.boardType == .v2
            icWallet.image = JadeAsset.img(.load, isV2 ? .v2 : .v1)
        }

        AnalyticsManager.shared.recordView(.verifyAddress, sgmt: AnalyticsManager.shared.sessSgmt(AccountsRepository.shared.current))
    }

    func setContent() {
        lblTitle.text = "id_confirm_on_your_device".localized
        icArrow.image = UIImage(named: "ic_hww_arrow")!.maskWithColor(color: UIColor.customMatrixGreen())

        if let transaction = transaction, let addressee = transaction.addressees.first {

            lblRecipientTitle.text = "id_recipient".localized
            lblRecipientAddress.text = addressee.address

            let addreessee = transaction.addressees.first
            let assetId = (account.gdkNetwork.liquid ) ? addreessee?.assetId ?? "" : "btc"
            let value = transaction.amounts.filter({$0.key == assetId}).first?.value ?? 0
            let registry = WalletManager.current
            if let balance = Balance.fromSatoshi(abs(value), assetId: assetId) {
                let (value, ticker) = balance.toValue()
                let (fiat, fiatCurrency) = balance.toFiat()
                lblAmount.text = value
                lblDenomination.text = "\(ticker)"
                lblFiat.text = "≈ \(fiat) \(fiatCurrency)"
            }
            lblFiat.isHidden = account.gdkNetwork.liquid
            icon.image = registry?.image(for: assetId)
            lblFeeTitle.text = "id_fee".localized
            if let balance = Balance.fromSatoshi(transaction.fee, assetId: account.gdkNetwork.getFeeAsset()) {
                let (amount, denom) = balance.toDenom()
                let (fiat, fiatCurrency) = balance.toFiat()
                lblFeeAmount.text = "\(amount) \(denom)"
                lblFeeFiat.text = "≈ \(fiat) \(fiatCurrency)"
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
                if output.isChange ?? false, let address = output.address {
                    changeAddress.append(address)
                }
            }
            if !changeAddress.isEmpty {
                lblChangeTitle.text = "id_change".localized
                lblChangeHint.text = changeAddress.map { "\($0)"}.joined(separator: "\n")
                lblChangeTitle.isHidden = false
                lblChangeHint.isHidden = false
            }
        }
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
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
