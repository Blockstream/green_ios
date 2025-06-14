import Foundation
import UIKit
import gdk
import core

class DialogReceiveVerifyAddressViewController: UIViewController {

    @IBOutlet weak var icArrow: UIImageView!
    @IBOutlet weak var icWallet: UIImageView!
    @IBOutlet weak var lblVerify: UILabel!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblAddress: UILabel!

    var isLedger = false
    var address = ""
    var walletItem: WalletItem?

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
        lblAddress.text = address

        if let walletItem = walletItem {
            AnalyticsManager.shared.recordView(.verifyAddress, sgmt: AnalyticsManager.shared.subAccSeg(AccountsRepository.shared.current, walletItem: walletItem))
        }
    }

    func setContent() {
        lblVerify.text = "id_verify_on_device".localized
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
