import UIKit

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
        var showDate = true
        var txtCache = ""
        _ = WalletManager.current
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
            if let fiat = Balance.fromSatoshi(amount.value, assetId: amount.key)?.toFiatText(),
               showPerAsset(amount.key, model) {
                if !fiat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // exist pricing for this non base asset
                    var txtLeft = ""
                    if model.amounts.count == 1 {
                        // add date only once
                        txtLeft = model.statusUI().label
                        showDate = false
                    }
                    addStackRow(
                        MultiLabelViewModel(
                            txtLeft: txtLeft,
                            txtRight: fiat,
                            hideBalance: hideBalance,
                            style: model.statusUI().style))
                }
            }
        }
        if showDate || model.amounts.count > 1 {
            // for base assets and multi asset txs add always the date below
            let satoshi = model.assetAmountList.policyAsset()
            let policyAsset = model.subaccount?.gdkNetwork.policyAsset ?? AssetInfo.btcId
            let fiat = Balance.fromSatoshi(satoshi, assetId: policyAsset)?.toFiatText()
            // hide fiat value for multi asset liquid (swaps)
            var txtRight = ""
            if model.amounts.count == 1 {
                txtRight = (satoshi != 0 ? fiat : nil) ?? ""
            }
            addStackRow(
                MultiLabelViewModel(
                    txtLeft: model.statusUI().label,
                    txtRight: txtRight,
                    hideBalance: hideBalance,
                    style: model.statusUI().style))
        }
        if !(model.tx.memo?.isEmpty ?? true) {
            if let row = Bundle.main.loadNibNamed("SingleLabelView", owner: self, options: nil)?.first as? SingleLabelView {
                row.configure(model.tx.memo ?? "")
                innerStack.addArrangedSubview(row)
            }
        }

        activity.isHidden = true
        self.onTap = onTap
    }
    func showPerAsset(_ asset: String, _ model: TransactionCellModel) -> Bool {
        // base assets: [btcId, testId, lbtcId, ltestId, lightningId]
        if asset == AssetInfo.btcId ||
            asset == AssetInfo.testId ||
            asset == AssetInfo.lightningId {
            return false
        }
        if model.amounts.count == 1 && (asset != AssetInfo.lbtcId && asset != AssetInfo.ltestId) {
            return true
        }
        if model.amounts.count > 1 {
            return true
        }
        return false
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
