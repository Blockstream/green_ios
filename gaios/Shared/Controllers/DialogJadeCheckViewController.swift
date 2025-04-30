import Foundation
import UIKit

class DialogJadeCheckViewController: UIViewController {

    @IBOutlet weak var icArrow: UIImageView!
    @IBOutlet weak var icWallet: UIImageView!
    @IBOutlet weak var lblVerify: UILabel!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblAddress: UILabel!

    var isLedger = false
    var message = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        view.alpha = 0.0

        if isLedger {
            icWallet.image = UIImage(named: "ic_hww_ledger")
        } else {
            let isV2 = BleHwManager.shared.jade?.version?.boardType == .v2
            icWallet.image = JadeAsset.img(.load, isV2 ? .v2 : .v1)
        }
    }

    func setContent() {
        lblVerify.text = "id_check_device".localized
        lblAddress.text = message
        icArrow.image = UIImage(named: "ic_hww_arrow")!.maskWithColor(color: UIColor.gAccent())
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func dismiss() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }

    @IBAction func btnDismiss(_ sender: Any) {
        dismiss()
    }
}
