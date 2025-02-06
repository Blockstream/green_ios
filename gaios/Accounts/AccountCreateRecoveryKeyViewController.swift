import UIKit
import core
import gdk

protocol AccountCreateRecoveryKeyDelegate: AnyObject {
    func didPublicKey(_ key: String)
    func didNewRecoveryPhrase(_ mnemonic: String)
    func didExistingRecoveryPhrase(_ mnemonic: String)
}

class AccountCreateRecoveryKeyViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!

    @IBOutlet weak var cardHW: UIView!
    @IBOutlet weak var lblHWTitle: UILabel!
    @IBOutlet weak var lblHWHint: UILabel!

    @IBOutlet weak var cardNewPhrase: UIView!
    @IBOutlet weak var lblNewPhraseTitle: UILabel!
    @IBOutlet weak var lblNewPhraseHint: UILabel!

    @IBOutlet weak var cardExistingPhrase: UIView!
    @IBOutlet weak var lblExistingPhraseTitle: UILabel!
    @IBOutlet weak var lblExistingPhraseHint: UILabel!

    @IBOutlet weak var cardPublicKey: UIView!
    @IBOutlet weak var lblPublicKeyTitle: UILabel!
    @IBOutlet weak var lblPublicKeyHint: UILabel!

    private var cards: [UIView] = []
    var session: SessionManager!
    weak var delegate: AccountCreateRecoveryKeyDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        cards = [cardHW, cardNewPhrase, cardExistingPhrase, cardPublicKey]
        setContent()
        setStyle()
        setActions()

        AnalyticsManager.shared.recordView(.addAccountChooseRecovery, sgmt: AnalyticsManager.shared.sessSgmt(AccountsRepository.shared.current))
    }

    func setContent() {
        lblTitle.text = "id_select_your_recovery_key".localized
        lblHWTitle.text = "id_hardware_wallet".localized
        lblHWHint.text = "id_use_a_hardware_wallet_as_your".localized
        lblNewPhraseTitle.text = "id_new_recovery_phrase".localized
        lblNewPhraseHint.text = "id_generate_a_new_recovery_phrase".localized
        lblExistingPhraseTitle.text = "id_existing_recovery_phrase".localized
        lblExistingPhraseHint.text = "id_use_an_existing_recovery_phrase".localized
        lblPublicKeyTitle.text = "id_use_a_public_key".localized
        lblPublicKeyHint.text = "id_use_an_xpub_for_which_you_own".localized
    }

    func setStyle() {
        cards.forEach { card in
            card.layer.cornerRadius = 5.0
        }
        cardHW.isHidden = true
    }

    func setActions() {
        cards.forEach { card in
            card.layer.cornerRadius = 5.0
        }
        cardHW.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didPressCardHW)))
        cardNewPhrase.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didPressCardNewPhrase)))
        cardExistingPhrase.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didPressCardExistingPhrase)))
        cardPublicKey.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didPressCardPublicKey)))
    }

    @objc func didPressCardHW() {
        next(.hw)
    }

    @objc func didPressCardNewPhrase() {
        next(.newPhrase)
    }

    @objc func didPressCardExistingPhrase() {
        next(.existingPhrase)
    }

    @objc func didPressCardPublicKey() {
        next(.publicKey)
    }

    func next(_ recoveryKeyType: RecoveryKeyType) {
        switch recoveryKeyType {
        case .hw:
            DropAlert().warning(message: "id_this_feature_is_coming_soon".localized, delay: 3)
        case .newPhrase:
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "OnBoardInfoViewController") as? OnBoardInfoViewController {
                OnBoardInfoViewController.flowType = .subaccount
                OnBoardInfoViewController.delegate = delegate
                navigationController?.pushViewController(vc, animated: true)
            }
        case .existingPhrase:
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "MnemonicViewController") as? MnemonicViewController {
                vc.mnemonicActionType = .addSubaccount
                vc.delegate = delegate
                navigationController?.pushViewController(vc, animated: true)
            }
        case .publicKey:
            let storyboard = UIStoryboard(name: "Accounts", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "AccountCreatePublicKeyViewController") as? AccountCreatePublicKeyViewController {
                vc.delegate = delegate
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
