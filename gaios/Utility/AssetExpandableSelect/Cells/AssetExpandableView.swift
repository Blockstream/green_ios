import UIKit
import gdk

class AssetExpandableView: UIView {
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var tapView: UIView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var ampTip: UIView!
    @IBOutlet weak var lblAmp: UILabel!

    func configure(
        model: AssetSelectCellModel,
        hasAccounts: Bool,
        open: Bool)
    {
        if open {
            bg.borderWidth = 2.0
            bg.borderColor = UIColor.gGreenMatrix()
            bg.layer.cornerRadius = 5
            bg.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else {
            bg.borderWidth = 0.0
        }
        ampTip.cornerRadius = 5.0
        // Any liquid asset
        if model.anyLiquid {
            title.text = "id_receive_any_liquid_asset".localized
            icon.image = UIImage(named: "default_asset_liquid_icon")!
            lblAmp.text = "id_you_need_a_liquid_account_in".localized
            ampTip.isHidden = !open
            return
        }
        // Any AMP asset
        if model.anyAmp {
            title.text = "Receive any Amp Asset".localized
            icon.image = UIImage(named: "default_asset_amp_icon")!
            lblAmp.text = "You need an AMP account in order to receive it.".localized
            ampTip.isHidden = !open
            return
        }
        // Any asset
        let name = model.asset?.name ?? model.asset?.assetId
        title.text = name
        icon?.image = model.icon
        ampTip.isHidden = !(model.asset?.amp ?? false && open)
        // Hide tooltip for btc / lbtc
        let btcIds = [AssetInfo.btcId, AssetInfo.testId, AssetInfo.lbtcId, AssetInfo.ltestId]
        if let asset = model.asset, btcIds.contains(asset.assetId) {
            ampTip.isHidden = true
            return
        }
        // Show amp tooltip
        if let asset = model.asset, asset.amp ?? false {
            if hasAccounts {
                lblAmp.text = String(format: "id_s_is_an_amp_asset_you_can".localized, asset.name ?? "")
            } else {
                lblAmp.text = String(format: "id_s_is_an_amp_asset_you_need_an".localized, asset.name ?? "")
            }
            ampTip.isHidden = !open
            return
        }
        // Show liquid tooltip
        else if let asset = model.asset {
            if hasAccounts {
                lblAmp.text = String(format: "id_s_is_a_liquid_asset_you_can".localized, asset.name ?? "")
            } else {
                lblAmp.text = String(format: "id_s_is_a_liquid_asset_you_need_a".localized, asset.name ?? "")
            }
            ampTip.isHidden = !open
        }
    }
}
