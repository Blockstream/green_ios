import Foundation
import UIKit
import LocalAuthentication
import core

class MnemonicAuthViewController: UIViewController {

    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var lblCard1Title: UILabel!
    @IBOutlet weak var lblCard2Title: UILabel!
    @IBOutlet weak var lblCard3Title: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setContent()
        setStyle()

        AnalyticsManager.shared.recordView(.recoveryIntro, sgmt: AnalyticsManager.shared.ntwSgmtUnified())
    }

    func setContent() {
        lblTitle.text = "id_recovery_phrase".localized
        lblHint.text = "id_the_recovery_phrase_can_be_used".localized
        lblCard1Title.text = "id_write_down_your_recovery_phrase".localized
        lblCard2Title.text = "id_dont_store_your_recovery_phrase".localized
        lblCard3Title.text = "id_dont_take_screenshots_of_your".localized
        btnNext.setTitle("id_continue".localized, for: .normal)
    }

    func setStyle() {
        btnNext.setStyle(.primary)
    }

    func authenticated(successAction: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authentication" ) { success, _ in
            if success {
                successAction()
            }
            }
        }
    }

    @IBAction func btnPressed(_ sender: Any) {
        self.authenticated {
            DispatchQueue.main.async { [unowned self] in

                let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "ShowMnemonicsViewController")
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
