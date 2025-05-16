import UIKit
import gdk
import core

class TransactionCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var innerStack: UIStackView!
    @IBOutlet weak var activity: UIActivityIndicatorView!

    class var identifier: String { return String(describing: self) }

    var onTap: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        bg.setStyle(CardStyle.defaultStyle)
        bg.addGestureRecognizer(tap)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        innerStack.subviews.forEach { $0.removeFromSuperview() }
    }

    func configure(model: TransactionCellModel, hideBalance: Bool, onTap: (() -> Void)?) {
        self.imgView.image = model.icon

        var txtCache = ""
        let registry = WalletManager.current
        for (idx, amount) in model.amounts.enumerated() {
            if let balance = Balance.fromSatoshi(amount.value, assetId: amount.key) {
                let (value, denom) = balance.toValue()
                let txtRight = "\(value) \(denom)"
                var txtLeft = ""
                if idx == 0 {
                    txtLeft = model.status ?? ""
                    txtCache = txtLeft
                } else {
                    if txtCache != model.status ?? "" {
                        txtLeft = model.status ?? ""
                    }
                }
                var style: MultiLabelStyle = amount.value > 0 ? .amountIn : .amountOut
                if model.tx.isRefundableSwap ?? false {
                    style = .swapFailure
                }
                addStackRow(MultiLabelViewModel(txtLeft: txtLeft,
                                                txtRight: txtRight,
                                                hideBalance: hideBalance,
                                                style: style))
            }
        }
        let satoshi = model.assetAmountList.satoshi()
        let policyAsset = model.subaccount?.gdkNetwork.policyAsset ?? AssetInfo.btcId
        let fiat = Balance.fromSatoshi(satoshi, assetId: policyAsset)?.toFiatText()
        addStackRow(
            MultiLabelViewModel(
                txtLeft: model.statusUI().label,
                txtRight: satoshi != 0 ? fiat : nil,
                hideBalance: nil,
                style: model.statusUI().style))
        if !(model.tx.memo?.isEmpty ?? true) {
            if let row = Bundle.main.loadNibNamed("SingleLabelView", owner: self, options: nil)?.first as? SingleLabelView {
                row.configure(model.tx.memo ?? "")
                innerStack.addArrangedSubview(row)
            }
        }

        activity.isHidden = true
        self.onTap = onTap
    }

    func addStackRow(_ model: MultiLabelViewModel) {
        if let row = Bundle.main.loadNibNamed("MultiLabelView", owner: self, options: nil)?.first as? MultiLabelView {
            row.configure(model)
            innerStack.addArrangedSubview(row)
        }
    }

    @objc func didTap() {
        bg.pressAnimate { [weak self] in
            self?.onTap?()
        }
    }
}
