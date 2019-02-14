import Foundation
import UIKit
import PromiseKit

class SystemMessageViewController: UIViewController {

    var systemMessage: Event!
    private var text: String {
        get { return systemMessage.value["text"] as! String }
    }

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var acceptLabel: UILabel!
    @IBOutlet weak var acceptCheck: DesignableButton!
    @IBOutlet weak var laterButton: UIButton!
    @IBOutlet weak var confirmButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("id_system_message", comment: "")
        textView.text = text
        acceptLabel.text = NSLocalizedString("id_i_confirm_i_have_read_and", comment: "")
        laterButton.setTitle(NSLocalizedString("id_later", comment: ""), for: .normal)
        confirmButton.setTitle(NSLocalizedString("id_accept", comment: ""), for: .normal)
        confirmButton.isEnabled = false
        updateButtons()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        confirmButton.updateGradientLayerFrame()
    }

    @IBAction func laterButtonClick(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func confirmButtonClick(_ sender: UIButton) {
        let bgq = DispatchQueue.global(qos: .background)
        Guarantee().map(on: bgq) {
            try getSession().ackSystemMessage(message: self.text)
        }.then(on: bgq) { twoFactorCall in
            twoFactorCall.resolve(self)
        }.done { _ in
            getGAService().reloadSystemMessage()
            self.navigationController?.popViewController(animated: true)
        }.catch { _ in
            print("Error on remove system message")
        }
    }

    @IBAction func acceptCheckClick(_ sender: Any) {
        confirmButton.isEnabled = !confirmButton.isEnabled
        updateButtons()
    }

    func updateButtons() {
        let accept = confirmButton.isEnabled
        acceptCheck.backgroundColor = accept ? UIColor.customMatrixGreen() : UIColor.clear
        acceptCheck.layer.borderColor =  UIColor.customTitaniumLight().cgColor
        acceptCheck.setImage(accept ? UIImage(named: "check") : nil, for: UIControlState.normal)
        acceptCheck.tintColor = UIColor.white
        confirmButton.toggleGradient(accept)
    }
}
