import UIKit

class ChooseSecurityViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var cardSimple: UIView!
    @IBOutlet weak var lblSimpleTitle: UILabel!
    @IBOutlet weak var lblSimpleHint: UILabel!

    @IBOutlet weak var cardAdvanced: UIView!
    @IBOutlet weak var lblAdvancedTitle: UILabel!
    @IBOutlet weak var lblAdvancedHint: UILabel!

    var isDebug = false

    override func viewDidLoad() {
        super.viewDidLoad()

        #if DEBUG
        isDebug = true
        #endif

        setContent()
        setStyle()
        setActions()

        view.accessibilityIdentifier = AccessibilityIdentifiers.ChooseSecurityScreen.view
        cardAdvanced.accessibilityIdentifier = AccessibilityIdentifiers.ChooseSecurityScreen.multiSigCard
    }

    func setContent() {
        lblTitle.text = NSLocalizedString("id_choose_security_policy", comment: "")
        lblHint.text = NSLocalizedString("id_once_selected_this_spending", comment: "")
        lblSimpleTitle.text = NSLocalizedString("id_singlesig", comment: "")
        lblSimpleHint.text = NSLocalizedString("id_your_funds_are_secured_by_a", comment: "")
        lblAdvancedTitle.text = NSLocalizedString("id_multisig_shield", comment: "")
        lblAdvancedHint.text = NSLocalizedString("id_your_funds_are_secured_by", comment: "")
    }

    func setStyle() {
        cardSimple.layer.cornerRadius = 5.0
        cardAdvanced.layer.cornerRadius = 5.0

        if !isDebug && OnBoardManager.shared.params?.network != "testnet" {
            cardSimple.alpha = 0.5
        }
    }

    func setActions() {
        let tapGesture1 = UITapGestureRecognizer(target: self, action: #selector(didPressCardSimple))
        cardSimple.addGestureRecognizer(tapGesture1)
        let tapGesture2 = UITapGestureRecognizer(target: self, action: #selector(didPressCardAdvanced))
        cardAdvanced.addGestureRecognizer(tapGesture2)
    }

    @objc func didPressCardSimple() {
        if !isDebug && OnBoardManager.shared.params?.network != "testnet" { return }
        OnBoardManager.shared.params?.singleSig = true
        next()
    }

    @objc func didPressCardAdvanced() {
        OnBoardManager.shared.params?.singleSig = false
        next()
    }

    func next() {
        switch LandingViewController.flowType {
        case .add:
            let storyboard = UIStoryboard(name: "Recovery", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "RecoveryInstructionViewController")
            navigationController?.pushViewController(vc, animated: true)
        case .restore:
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "RecoveryPhraseViewController")
            navigationController?.pushViewController(vc, animated: true)
        }

    }
}
