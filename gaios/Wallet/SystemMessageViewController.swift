import Foundation
import UIKit
import core
import gdk

class SystemMessageViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var acceptLabel: UILabel!
    @IBOutlet weak var acceptCheck: DesignableButton!
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var confirmBtn: UIButton!
    var msg: SystemMessage!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "id_system_message".localized
        textView.text = msg.text
        acceptLabel.text = "id_i_confirm_i_have_read_and".localized
        cancelBtn.setTitle("id_later".localized, for: .normal)
        confirmBtn.setTitle("id_accept".localized, for: .normal)
        confirmBtn.isEnabled = false
        reload()

        AnalyticsManager.shared.recordView(.systemMessage, sgmt: AnalyticsManager.shared.sessSgmt(AccountsRepository.shared.current))
    }

    func reload() {
        let accept = confirmBtn.isEnabled
        acceptCheck.backgroundColor = accept ? UIColor.gAccent() : UIColor.clear
        acceptCheck.setImage(accept ? UIImage(named: "check") : nil, for: UIControl.State.normal)
        acceptCheck.tintColor = UIColor.white
        acceptCheck.layer.borderWidth = 1.0
        acceptCheck.layer.borderColor =  UIColor.customTitaniumLight().cgColor
        acceptCheck.layer.cornerRadius = 2.0
        if accept {
            confirmBtn.setStyle(.primary)
        } else {
            confirmBtn.setStyle(.primaryDisabled)
        }
    }

    @IBAction func acceptCheckClick(_ sender: Any) {
        confirmBtn.isEnabled = !confirmBtn.isEnabled
        reload()
    }

    @IBAction func cancelBtn(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func confirmBtn(_ sender: Any) {
        let session = WalletManager.current?.sessions.filter { $0.key == msg.network }.values.first
        Task {
            do {
                try await session?.ackSystemMessage(message: self.msg.text)
                navigationController?.popViewController(animated: true)
            } catch {
                self.showError("Error on system message")
            }
        }
    }
}
