import Foundation
import UIKit
import LocalAuthentication
class ManualBackupViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblInfo1: UILabel!
    @IBOutlet weak var lblInfo2: UILabel!
    @IBOutlet weak var lblInfo3: UILabel!
    @IBOutlet weak var btnNext: UIButton!
    var showBip85: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        title = "Back Up Your Wallet".localized
    }

    func setContent() {
        lblTitle.text = "Manual Backup".localized
        lblInfo1.text = "Offline, written backup".localized
        lblInfo2.text = "Access wallet on a new device".localized
        lblInfo3.text = "Instant recovery".localized
        btnNext.setTitle("Back Up Recovery Phrase", for: .normal)
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblInfo1.setStyle(.txt)
        lblInfo2.setStyle(.txt)
        lblInfo3.setStyle(.txt)
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
    @IBAction func btnNext(_ sender: Any) {
        self.authenticated {
            DispatchQueue.main.async { [weak self] in
                let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "ShowMnemonicsViewController") as? ShowMnemonicsViewController {
                    vc.showBip85 = self?.showBip85 ?? false
                    self?.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
    }
}
