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
}

class AlertCardCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnRight: UIButton!
    @IBOutlet weak var btnLeft: UIButton!
    @IBOutlet weak var btnsContainer: UIView!
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

    func configure(_ model: AlertCardCellModel,
                   onLeft: (() -> Void)?,
                   onRight: (() -> Void)?,
                   onDismiss: (() -> Void)?
    ) {
        self.backgroundColor = UIColor.customTitaniumDark()
        bg.layer.cornerRadius = 6.0

        self.onLeft = onLeft
        self.onRight = onRight
        self.onDismiss = onDismiss

        btnsContainer.isHidden = false
        iconWarn.isHidden = true
        btnDismiss.isHidden = true

        switch model.type {
        case .reset(let message):
            lblTitle.text = "id_2fa_reset_in_progress".localized
            lblHint.text = String(format: "id_your_wallet_is_locked_for_a".localized, message.twoFactorReset.daysRemaining)
            btnRight.setTitle("id_learn_more".localized, for: .normal)
            btnLeft.isHidden = true
        case .dispute(_):
            lblTitle.text = "id_2fa_dispute_in_progress".localized
            lblHint.text = "id_warning_wallet_locked_by".localized
            btnRight.setTitle("id_learn_more".localized, for: .normal)
            btnLeft.isHidden = true
        case .reactivate:
            lblTitle.text = "id_2fa_expired".localized
            lblHint.text = "id_show_coins_with_expiring".localized
            btnRight.setTitle("id_learn_more".localized, for: .normal)
            btnLeft.setTitle("Reactivate 2FA".localized, for: .normal)
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
                    return (txt ?? "") + "\n\n" + "Ensure your app is up to date.".localized
                case LoginError.walletNotFound(let txt):
                    return txt ?? ""
                case LoginError.hostUnblindingDisabled(_):
                    return "Some wallet functionalities have been disabled or will not work properly"
                case TwoFactorCallError.failure(let txt), TwoFactorCallError.cancel(let txt):
                    return txt
                default:
                    return error.description()?.localized ?? error.localizedDescription
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
            lblHint.text = "Some coins are no longer 2FA protected.".localized
            btnRight.setTitle("id_reenable_2fa".localized, for: .normal)
            btnLeft.isHidden = true
        }
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
