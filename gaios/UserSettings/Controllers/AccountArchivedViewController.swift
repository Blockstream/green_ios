import Foundation
import UIKit
import gdk
import core

protocol AccountArchivedViewControllerDelegate: AnyObject {
    func onDismissArchived()
    func showArchived()
}

class AccountArchivedViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnContinue: UIButton!

    @IBOutlet weak var btnArchive: UIButton!
    @IBOutlet weak var animateView: UIView!

    var wm: WalletManager { WalletManager.current! }

    var subaccounts: [WalletItem] {
        wm.subaccounts.filter { $0.hidden }
    }

    weak var delegate: AccountArchivedViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()
        view.alpha = 0.0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
        let riveView = RiveModel.animationArchived.createRiveView()
        riveView.frame = CGRect(x: 0.0, y: 0.0, width: animateView.frame.width, height: animateView.frame.height)
        animateView.addSubview(riveView)
    }

    func setContent() {
        lblTitle.text = "id_account_archived".localized
        lblHint.text = "id_you_can_still_receive_funds_but".localized
        btnContinue.setTitle("id_continue".localized, for: .normal)
        btnArchive.setTitle(String(format: "id_see_archived_accounts_s".localized, String(subaccounts.count)), for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.alert)
        lblTitle.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        lblHint.font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
        lblTitle.textColor = .white
        lblHint.textColor = .white.withAlphaComponent(0.6)
        btnContinue.setStyle(.primary)
        btnArchive.setStyle(.inline)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }

    @IBAction func btnContinue(_ sender: Any) {
        dismiss()
        delegate?.onDismissArchived()
    }

    @IBAction func btnArchive(_ sender: Any) {
        dismiss()
        delegate?.showArchived()
    }
}
