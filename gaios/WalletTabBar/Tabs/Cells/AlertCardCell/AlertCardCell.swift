import UIKit
import gdk
import core

enum AlertCardType {
    case reset(TwoFactorResetMessage)
    case dispute(TwoFactorResetMessage)
    case reactivate
    case systemMessage(SystemMessage)
    case fiatMissing
    case testnetNoValue
    case ephemeralWallet
    case remoteAlert(RemoteAlert)
    case login(String, Error)
    case lightningMaintenance
    case lightningServiceDisruption
    case reEnable2fa
    case backup
    case descriptorInfo
}

class AlertCardCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnRight: UIButton!
    @IBOutlet weak var btnLeft: UIButton!
    @IBOutlet weak var btnsContainer: UIStackView!
    @IBOutlet weak var iconWarn: UIImageView!
    @IBOutlet weak var btnDismiss: UIButton!

    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?
    var onDismiss: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func prepareForReuse() {
        btnsContainer.isHidden = false
        btnRight.isHidden = false
        btnLeft.isHidden = false
    }

    func setStyle() {
        bg.layer.cornerRadius = 5.0
        [btnLeft, btnRight].forEach {
            $0?.setStyle(.outlinedWhite)
        }
        btnLeft.backgroundColor = .white
        btnLeft.setTitleColor(UIColor.gBlackBg(), for: .normal)
        bg.borderWidth = 1
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtCard)
    }

    func configure(_ model: AlertCardCellModel,
                   onLeft: (() -> Void)?,
                   onRight: (() -> Void)?,
                   onDismiss: (() -> Void)?
    ) {
        self.onLeft = onLeft
        self.onRight = onRight
        self.onDismiss = onDismiss

        btnsContainer.isHidden = false
        iconWarn.isHidden = true
        btnDismiss.isHidden = true

        setStyle()

        iconWarn.image = UIImage(named: "ic_card_warn_blue")
        iconWarn.isHidden = false
        bg.backgroundColor = UIColor.gWarnCardBgBlue()
        bg.borderColor = UIColor.gWarnCardBorderBlue()

        switch model.type {
        case .reset(let message):
            lblTitle.text = "id_2fa_reset_in_progress".localized
            lblHint.text = String(format: "id_your_wallet_is_locked_for_a".localized, message.twoFactorReset.daysRemaining)
            btnRight.setTitle("id_learn_more".localized, for: .normal)
            btnLeft.isHidden = true
            styleWarn()
        case .dispute:
            lblTitle.text = "id_2fa_dispute_in_progress".localized
            lblHint.text = "id_warning_wallet_locked_by".localized
            btnRight.setTitle("id_learn_more".localized, for: .normal)
            btnLeft.isHidden = true
            styleWarn()
        case .reactivate:
            lblTitle.text = "id_2fa_expired".localized
            lblHint.text = "id_show_coins_with_expiring".localized
            btnRight.setTitle("id_learn_more".localized, for: .normal)
            btnLeft.setTitle("id_reactivate_2fa".localized, for: .normal)
            styleWarn()
        case .systemMessage(let system):
            lblTitle.text = "id_system_message".localized
            lblHint.text = system.text.count > 200 ? system.text.prefix(200) + " ..." : system.text
            btnRight.setTitle("id_accept".localized, for: .normal)
            btnLeft.isHidden = true
        case .fiatMissing:
            lblTitle.text = "id_warning".localized
            lblHint.text = "id_your_favourite_exchange_rate_is".localized
            btnRight.isHidden = true
            btnLeft.isHidden = true
            btnsContainer.isHidden = true
        case .testnetNoValue:
            lblTitle.text = "id_warning".localized
            lblHint.text = "id_this_wallet_operates_on_a_test".localized
            btnRight.isHidden = true
            btnLeft.isHidden = true
            btnsContainer.isHidden = true
        case .ephemeralWallet:
            lblTitle.text = "id_passphrase_protected".localized
            lblHint.text = "id_this_wallet_is_based_on_your".localized
            btnRight.isHidden = true
            btnLeft.isHidden = true
            btnsContainer.isHidden = true
        case .remoteAlert(let remoteAlert):
            lblTitle.text = remoteAlert.title?.htmlDecoded
            lblHint.text = remoteAlert.message?.htmlDecoded
            lblTitle.isHidden = remoteAlert.title?.isEmpty ?? true
            lblHint.isHidden = remoteAlert.message?.isEmpty ?? true
            btnRight.setTitle("id_learn_more".localized, for: .normal)
            btnRight.isHidden = onRight == nil
            btnLeft.isHidden = true
            btnsContainer.isHidden = onRight == nil
            if remoteAlert.isWarning ?? false {
                iconWarn.isHidden = false
            }
            if remoteAlert.dismissable ?? false {
                btnDismiss.isHidden = false
            }
        case .login(let network, let error):
            lblTitle.text = "id_warning".localized
            let errorString: String = {
                switch error {
                case LoginError.connectionFailed(let txt):
                    return (txt ?? "") + "\n\n" + "id_ensure_your_app_is_up_to_date".localized
                case LoginError.walletNotFound(let txt):
                    return txt ?? ""
                case LoginError.hostUnblindingDisabled(_):
                    return "Some wallet functionalities have been disabled or will not work properly"
                case TwoFactorCallError.failure(let txt), TwoFactorCallError.cancel(let txt):
                    return txt
                default:
                    return error.description().localized
                }
            }()

            let networkName = NetworkSecurityCase(rawValue: network)?.name()
            btnRight.isHidden = true
            btnLeft.isHidden = true
            btnsContainer.isHidden = true
            lblHint.text = "In network \(networkName ?? ""): \(errorString.localized)"
            switch error {
            case LoginError.hostUnblindingDisabled(_):
                lblHint.text = "\(errorString.localized)"
                btnRight.setTitle("id_try_again".localized, for: .normal)
                btnRight.isHidden = false
                btnsContainer.isHidden = false
            default:
                break
            }
        case .lightningMaintenance:
            lblTitle.text = "id_lightning_account".localized
            lblHint.text = "id_lightning_service_is_undergoing".localized
            lblHint.text = "id_this_wallet_is_based_on_your".localized
            btnRight.isHidden = true
            btnLeft.isHidden = true
            btnsContainer.isHidden = true
        case .lightningServiceDisruption:
            lblTitle.text = "id_lightning_account".localized
            lblHint.text = "id_the_lightning_service_is".localized
            btnRight.isHidden = true
            btnLeft.isHidden = true
            btnsContainer.isHidden = true
        case .reEnable2fa:
            lblTitle.text = "id_reenable_2fa".localized
            lblHint.text = "id_some_coins_are_no_longer_2fa".localized
            btnRight.setTitle("id_reenable_2fa".localized, for: .normal)
            btnLeft.isHidden = true
            styleWarn()
        case .backup:
            lblTitle.text = "id_back_up_your_wallet_now".localized
            lblHint.text = "id_dont_lose_access_to_your_funds".localized
            btnLeft.setTitle("id_backup_now".localized, for: .normal)
            btnRight.isHidden = true
            btnDismiss.isHidden = onDismiss == nil
            styleWarn()
        case .descriptorInfo:
            lblTitle.isHidden = true
            lblHint.text = "You can use your descriptor to view your balance in the Blockstream app without the ability to spend.".localized
            btnLeft.isHidden = true
            btnRight.isHidden = true
            btnsContainer.isHidden = true
            btnDismiss.isHidden = onDismiss == nil
        }
    }
    func styleWarn() {
        iconWarn.image = UIImage(named: "ic_card_warn")
        bg.backgroundColor = UIColor.gWarnCardBg()
        bg.borderColor = UIColor.gWarnCardBorder()
    }
    @IBAction func btnRight(_ sender: Any) {
        onRight?()
    }

    @IBAction func btnLeft(_ sender: Any) {
        onLeft?()
    }

    @IBAction func onDismiss(_ sender: Any) {
        onDismiss?()
    }
}
