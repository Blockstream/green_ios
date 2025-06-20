import Foundation
import UIKit
import LocalAuthentication
import core

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
        navigationItem.backButtonTitle = "id_back".localized
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
    @IBAction func btnNext(_ sender: Any) {
        if let vc = AccountNavigator.mnemonic() {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
