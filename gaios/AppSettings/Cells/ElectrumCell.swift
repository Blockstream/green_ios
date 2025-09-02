import UIKit
import core

class ElectrumCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var bgTls: UIView!
    @IBOutlet weak var lblTls: UILabel!
    @IBOutlet weak var switchTls: UISwitch!

    @IBOutlet weak var lblTitleBTC: UILabel!
    @IBOutlet weak var lblTitleLiquid: UILabel!
    @IBOutlet weak var lblTitleTestnet: UILabel!
    @IBOutlet weak var lblTitleLiquidTestnet: UILabel!

    @IBOutlet weak var bgBTC: UIView!
    @IBOutlet weak var bgLiquid: UIView!
    @IBOutlet weak var bgTestnet: UIView!
    @IBOutlet weak var bgLiquidTestnet: UIView!

    @IBOutlet weak var fieldBTC: UITextField!
    @IBOutlet weak var fieldLiquid: UITextField!
    @IBOutlet weak var fieldTestnet: UITextField!
    @IBOutlet weak var fieldLiquidTestnet: UITextField!

    var model: ElectrumCellModel?
    var onSwitchTls: (() -> Void)?
    var onChangeBTC: ((String) -> Void)?
    var onChangeLiquid: ((String) -> Void)?
    var onChangeTestnet: ((String) -> Void)?
    var onChangeLiquidTestnet: ((String) -> Void)?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 6.0
        lblTls.setStyle(.txtBigger)
        lblTls.text = "id_enable_tls".localized
        lblTitleBTC.text = "id_bitcoin_electrum_server".localized
        lblTitleLiquid.text = "id_liquid_electrum_server".localized
        lblTitleTestnet.text = "id_testnet_electrum_server".localized
        lblTitleLiquidTestnet.text = "id_liquid_testnet_electrum_server".localized
        fieldBTC.placeholder = GdkSettings.btcElectrumSrvDefaultEndPoint
        fieldLiquid.placeholder = GdkSettings.liquidElectrumSrvDefaultEndPoint
        fieldTestnet.placeholder = GdkSettings.testnetElectrumSrvDefaultEndPoint
        fieldLiquidTestnet.placeholder = GdkSettings.liquidTestnetElectrumSrvDefaultEndPoint
        [lblTitleBTC, lblTitleLiquid, lblTitleTestnet, lblTitleLiquidTestnet].forEach {
            $0?.setStyle(.txtCard)
        }
        [fieldBTC, fieldLiquid, fieldTestnet, fieldLiquidTestnet].forEach {
            $0.textColor = .white
            $0.addDoneButtonToKeyboard(myAction: #selector($0.resignFirstResponder))
        }
        [bgTls, bgBTC, bgLiquid, bgTestnet, bgLiquidTestnet].forEach {
            $0.setStyle(CardStyle.defaultStyle)
        }
        if !Bundle.main.dev {
            [lblTitleTestnet, lblTitleLiquidTestnet, bgTestnet, bgLiquidTestnet].forEach {
                $0.isHidden = true
            }
        }
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(model: ElectrumCellModel,
                   switchTlsState: Bool?,
                   onSwitchTls: (() -> Void)?,
                   onChangeBTC: ((String) -> Void)?,
                   onChangeLiquid: ((String) -> Void)?,
                   onChangeTestnet: ((String) -> Void)?,
                   onChangeLiquidTestnet: ((String) -> Void)?
    ) {
        self.model = model
        self.switchTls.isOn = model.switchTls
        self.onSwitchTls = onSwitchTls
        self.fieldBTC.text = model.serverBTC
        self.fieldLiquid.text = model.serverLiquid
        self.fieldTestnet.text = model.serverTestnet
        self.fieldLiquidTestnet.text = model.serverLiquidtestnet
        self.onChangeBTC = onChangeBTC
        self.onChangeLiquid = onChangeLiquid
        self.onChangeTestnet = onChangeTestnet
        self.onChangeLiquidTestnet = onChangeLiquidTestnet
    }
    @IBAction func switchTls(_ sender: Any) {
        onSwitchTls?()
    }
    @IBAction func didChangeBTC(_ sender: Any) {
        onChangeBTC?(fieldBTC.text ?? "")
    }
    @IBAction func didChangeLiquid(_ sender: Any) {
        onChangeBTC?(fieldLiquid.text ?? "")
    }
    @IBAction func didChangeTestnet(_ sender: Any) {
        onChangeBTC?(fieldTestnet.text ?? "")
    }
    @IBAction func didChangeLiquidTestnet(_ sender: Any) {
        onChangeBTC?(fieldLiquidTestnet.text ?? "")
    }
}
