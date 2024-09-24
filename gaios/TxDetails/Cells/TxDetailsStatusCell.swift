import UIKit
import gdk
import core

class TxDetailsStatusCell: UITableViewCell {

    @IBOutlet weak var stateView: UIView!
    @IBOutlet weak var stateIcon: UIImageView!

    @IBOutlet weak var iconsView: UIView!
    @IBOutlet weak var iconsStack: UIStackView!

    @IBOutlet weak var swapIconsView: UIView!
    @IBOutlet weak var swapIconsStack: UIStackView!

    @IBOutlet weak var lblStateTitle: UILabel!
    @IBOutlet weak var lblStateInfo: UILabel!
    @IBOutlet weak var lblStateDate: UILabel!
    @IBOutlet weak var lblStateStatus: UILabel!
    @IBOutlet weak var bgLblStatus: UIView!
    @IBOutlet weak var iconsStackWidth: NSLayoutConstraint!
    @IBOutlet weak var swapIconsStackWidth: NSLayoutConstraint!

    @IBOutlet weak var spvStack: UIStackView!
    @IBOutlet weak var iconSpv: UIImageView!
    @IBOutlet weak var lblSpv: UILabel!

    class var identifier: String { return String(describing: self) }

    var model: TxDetailsStatusCellModel?

    private let iconW: CGFloat = 36.0

    override func awakeFromNib() {
        super.awakeFromNib()
        [stateView, bgLblStatus].forEach {
            $0.cornerRadius = $0.frame.size.height / 2.0
        }
        swapIconsView.isHidden = true
    }

    func configure(model: TxDetailsStatusCellModel) {
        self.model = model

        setStyle()
        setAssetIcons()

        lblStateDate.text = model.transaction.date(dateStyle: .long, timeStyle: .short)
        lblStateDate.isHidden = model.transaction.createdAtTs == 0

        lblStateInfo.text = model.txStatusExtended

        var step: Int = 0
        var steps: Int = 0
        steps = model.transaction.isLiquid ? 2 : 6
        let isLightning = model.transaction.subaccountItem?.gdkNetwork.lightning ?? false

        if model.transaction.isRefundableSwap ?? false {
            lblStateTitle.text = "id_transaction_failed".localized
            lblStateInfo.text = String(format: "id_your_transaction_failed_s".localized, "")
            lblStateStatus.text = NSLocalizedString("id_failed", comment: "")
            applyColor(UIColor.gRedTx())
            stateIcon.image = UIImage(named: "ic_tx_failed")!
        } else if model.transaction.isUnconfirmed(block: model.blockHeight) {
            lblStateTitle.text = String(format: "id_transaction_unconfirmed_ss".localized, "0", "6")
            lblStateStatus.text = model.txUnconfirmedStatus
            applyColor(UIColor.gOrangeTx())
            setPendingIcon()
        } else if !isLightning && model.transaction.isLiquid && model.blockHeight < model.transaction.blockHeight + 1 {
            step = Int(model.blockHeight) - Int(model.transaction.blockHeight) + 1
            lblStateTitle.text = String(format: "id_transaction_unconfirmed_ss".localized, "\(step)", "\(steps)")
            lblStateStatus.text = model.txStatus
            applyColor(UIColor.gOrangeTx())
            setPendingIcon()
        } else if !isLightning && !model.transaction.isLiquid && model.blockHeight < model.transaction.blockHeight + 5 {
            if model.blockHeight >= model.transaction.blockHeight {
                step = Int(model.blockHeight) - Int(model.transaction.blockHeight) + 1
                lblStateTitle.text = String(format: "id_transaction_confirmed_ss".localized, "\(step)", "\(steps)")
                lblStateStatus.text = model.txStatus
                applyColor(UIColor.gGreenTx())
                stateIcon.image = UIImage(named: "ic_tx_confirmed")!
            }
        } else {
            applyColor(UIColor.gGreenTx())
            lblStateTitle.text = "id_transaction_completed".localized
            lblStateStatus.text = model.txStatus
            if isLightning && !(model.transaction.closingTxid?.isEmpty ?? true) {
                lblStateStatus.text = "id_close_channel".localized
            }
            stateIcon.image = UIImage(named: "ic_tx_confirmed")!
        }

        if !shouldShowSpvStatus(tx: model.transaction) {
            spvStack.isHidden = true
        } else {
            spvStack.isHidden = false
            setIconSpv(tx: model.transaction)
            setLblSpv(transaction: model.transaction)
        }
    }

    func setStyle() {
        lblStateTitle.setStyle(.subTitle)
        lblStateInfo.setStyle(.txt)
        lblStateDate.setStyle(.txt)
        lblStateDate.textColor = UIColor.gGrayTxt()
        lblStateStatus.setStyle(.txtSmallerBold)
    }

    func applyColor(_ color: UIColor) {
        [stateView, bgLblStatus].forEach {
            $0.backgroundColor = color
        }
    }

    func setAssetIcons() {
        guard let model = model else { return }

        for v in iconsStack.subviews { v.removeFromSuperview() }
        for v in swapIconsStack.subviews { v.removeFromSuperview() }

        if model.transaction.type == .mixed {

            swapIconsView.isHidden = false

            var iconsOut: [UIImage] = []
            var iconsIn: [UIImage] = []
            let ids_values = model.assetAmountList.amounts.map { ($0.0, $0.1) }
            for (id, value) in ids_values {
                let icon = model.assetAmountList.image(for: id)
                if value < 0 {
                    iconsOut.append(icon)
                } else {
                    iconsIn.append(icon)
                }
            }

            fillIconsStack(iconsOut)
            fillSwapIconsStack(iconsIn)

        } else if model.transaction.type == .redeposit {

            let amounts = model.transaction.amounts
            var icons: [UIImage] = []
            if model.transaction.subaccountItem?.gdkNetwork.lightning ?? false {
                icons = [UIImage(named: "ic_lightning_btc")!]
            } else {
                let registry = WalletManager.current
                let ids = amounts.map { $0.0 }
                for asset in ids {
                    let icon = registry?.image(for: asset) ?? UIImage()
                    if icons.count > 0 {
                        if icon != icons.last {
                            icons.append(icon)
                        }
                    } else {
                        icons.append(icon)
                    }
                }
                icons = Array(icons.prefix(10))
                fillIconsStack(icons)
            }
        } else {
            var icons: [UIImage] = []
            if model.transaction.subaccountItem?.gdkNetwork.lightning ?? false {
                icons = [UIImage(named: "ic_lightning_btc")!]
            } else {
                let ids = model.assetAmountList.amounts.map { $0.0 }
                for asset in ids {
                    let icon = model.assetAmountList.image(for: asset)
                    if icons.count > 0 {
                        if icon != icons.last {
                            icons.append(icon)
                        }
                    } else {
                        icons.append(icon)
                    }
                }
            }
            icons = Array(icons.prefix(10))
            fillIconsStack(icons)
        }
    }

    func fillIconsStack(_ icons: [UIImage]) {
        iconsStackWidth.constant = CGFloat(icons.count) * iconW - CGFloat(icons.count - 1) * 5.0
        for img in icons {
            let imageView = UIImageView()
            imageView.image = img
            imageView.borderColor = UIColor.gBlackBg()
            imageView.borderWidth = 2.0
            imageView.layer.cornerRadius = iconW / 2.0
            imageView.layer.masksToBounds = true
            iconsStack.addArrangedSubview(imageView)
        }
    }

    func fillSwapIconsStack(_ icons: [UIImage]) {
        swapIconsStackWidth.constant = CGFloat(icons.count) * iconW - CGFloat(icons.count - 1) * 5.0
        for img in icons {
            let imageView = UIImageView()
            imageView.image = img
            imageView.borderColor = UIColor.gBlackBg()
            imageView.borderWidth = 2.0
            imageView.layer.cornerRadius = iconW / 2.0
            imageView.layer.masksToBounds = true
            swapIconsStack.addArrangedSubview(imageView)
        }
    }

    func setPendingIcon() {
        stateIcon.image = UIImage(named: "ic_tx_pending")!
        stateIcon.rotate()
    }

    func shouldShowSpvStatus(tx: Transaction) -> Bool {

        let appSettings = AppSettings.shared
        guard let gdkSettings = appSettings.gdkSettings else { return false }
        if gdkSettings.spvEnabled == false { return false }

        if tx.spvVerified == "disabled" || tx.spvVerified == nil {
            return false
        }
        if tx.blockHeight == 0 {
            // return false
        }
        if let account = subaccount(tx: tx), let session = account.session,
           Int(session.blockHeight) - Int(tx.blockHeight) + 1 < 6 {
            return false
        }
        return true
    }

    func subaccount(tx: Transaction) -> WalletItem? {
        return WalletManager.current?.subaccounts.filter { $0.hashValue == tx.subaccount }.first
    }

    func setIconSpv(tx: Transaction) {
        switch tx.spvVerified {
        case "disabled", nil:
            iconSpv.isHidden = true
        case "verified":
            iconSpv.isHidden = false
            iconSpv.image = UIImage(named: "ic_spv_check")
            iconSpv.tintColor = UIColor.gGreenMatrix()
        case "in_progress":
            iconSpv.isHidden = false
            iconSpv.image = UIImage(named: "ic_spv_progress")
            iconSpv.tintColor = .white
        case "not_verified":
            iconSpv.isHidden = false
            iconSpv.image = UIImage(named: "ic_spv_warning")
            iconSpv.tintColor = .red
        default:
            iconSpv.isHidden = false
            iconSpv.image = UIImage(named: "ic_spv_warning")
            iconSpv.tintColor = .yellow
        }
    }

    func setLblSpv(transaction: Transaction) {
        lblSpv.isHidden = ["disabled", nil].contains(transaction.spvVerified)

        switch transaction.spvVerified {
        case "verified":
            lblSpv.textColor = UIColor.customMatrixGreen()
            lblSpv.text = "id_verified".localized
        case "not_verified":
            lblSpv.textColor = .red
            lblSpv.text = "id_invalid_merkle_proof".localized
        case "not_longest":
            lblSpv.textColor = .yellow
            lblSpv.text = "id_not_on_longest_chain".localized
        default:
            lblSpv.textColor = UIColor.gW60()
            lblSpv.text = "Verifying…".localized
        }
    }
}
