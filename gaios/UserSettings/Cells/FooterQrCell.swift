import UIKit

class FooterQrCell: UICollectionReusableView {

    @IBOutlet weak var passphraseView: UIView!
    @IBOutlet weak var lblPassphraseTitle: UILabel!
    @IBOutlet weak var lblPassphraseValue: UILabel!
    @IBOutlet weak var btnLearn: UIButton!
    @IBOutlet weak var lblQrInfo: UILabel!
    @IBOutlet weak var bip85View: UIView!
    @IBOutlet weak var infoPanel: UIView!
    @IBOutlet weak var lblBip85: UILabel!

    var mnemonic: String?

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func configure(mnemonic: String?,
                   bip39Passphrase: String?) {
        self.mnemonic = mnemonic
        let isEphemeral = bip39Passphrase != nil
        passphraseView.isHidden = !isEphemeral
        lblQrInfo.isHidden = !isEphemeral
        if isEphemeral {
            lblQrInfo.text = NSLocalizedString("id_the_qr_code_does_not_include", comment: "")
            lblPassphraseTitle.text = NSLocalizedString("id_bip39_passphrase", comment: "")
            lblPassphraseValue.text = bip39Passphrase ?? ""
            btnLearn.setTitle(NSLocalizedString("id_learn_more", comment: ""), for: .normal)
            btnLearn.setTitleColor(UIColor.customMatrixGreen(), for: .normal)
        }
        bip85View.isHidden = true
    }

    func configureBip85(mnemonic: String?) {
        self.mnemonic = mnemonic
        passphraseView.isHidden = true
        lblQrInfo.isHidden = true
        bip85View.isHidden = false
        infoPanel.cornerRadius = 5.0
        infoPanel.backgroundColor = UIColor.gGreenFluo().withAlphaComponent(0.2)
        lblBip85.text = "This is your BIP85 derived recovery phrase only for your Lightning account.\n\nWARNING: You can't fully restore your wallet with that.".localized
    }

    @IBAction func btnLearnMore(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.passphraseReadMore)
    }
}
