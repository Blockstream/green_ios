import Foundation
import UIKit

enum OTAAction {
    case update
    case readMore
    case cancel
}

class DialogOTAViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var btnUpdate: UIButton!
    @IBOutlet weak var btnReadMore: UIButton!
    @IBOutlet weak var btnCancel: UIButton!

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    var onSelect: ((OTAAction) -> Void)?
    var needCableUpdate = false
    var isRequired = false
    var firrmwareVersion: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        view.alpha = 0.0
    }

    func setContent() {

        btnUpdate.setTitle("id_update".localized, for: .normal)
        btnUpdate.isHidden = needCableUpdate
        btnReadMore.setTitle("id_read_more", for: .normal)
        btnReadMore.isHidden = !needCableUpdate
        btnCancel.setTitle("id_cancel".localized, for: .normal)

        lblTitle.text = isRequired ? "id_new_jade_firmware_required".localized : "id_new_jade_firmware_available".localized

        if needCableUpdate {
            lblHint.text = "id_connect_jade_with_a_usb_cable".localized
        } else {
            lblHint.text = String(format: "id_version_1s".localized, firrmwareVersion)
        }
    }

    func setStyle() {
        btnUpdate.setStyle(.primary)
        btnReadMore.setStyle(.primary)
        btnCancel.setStyle(.outlined)
        cardView.setStyle(.bottomsheet)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func dismiss(_ action: OTAAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                self.onSelect?(action)
            })
        })
    }

    @IBAction func btnUpdate(_ sender: Any) {
        dismiss(.update)
    }

    @IBAction func btnReadMore(_ sender: Any) {
        dismiss(.readMore)
    }

    @IBAction func btncancel(_ sender: Any) {
        dismiss(.cancel)
    }
}
