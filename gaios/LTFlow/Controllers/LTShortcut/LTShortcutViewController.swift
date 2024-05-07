import Foundation
import UIKit

protocol LTShortcutViewControllerDelegate: AnyObject {
    func onTap(_ action: LTShortcutUserAction)
}

enum LTShortcutUserAction {
    case learnMore
    case done
    case remove
}

class LTShortcutViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var btnLearnMore: UIButton!
    @IBOutlet weak var btnMain: UIButton!
    @IBOutlet weak var lblJadeExtraNote: UILabel!

    weak var delegate: LTShortcutViewControllerDelegate?

    var vm: LTShortcutViewModel!

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
    }

    func setContent() {
        lblTitle.text = vm.title
        lblHint.text = vm.hint
        btnLearnMore.setTitle(vm.btnMore, for: .normal)
        btnMain.setTitle(vm.btnMain, for: .normal)
        lblJadeExtraNote.isHidden = true
        lblJadeExtraNote.text = "You will need to export the account from Jade at your next login.".localized
        switch vm.action {
        case .addFromAccount:
            DrawerAnimationManager.shared.accountId = vm.account.id
        case .addFromCreate:
            DrawerAnimationManager.shared.accountId = vm.account.id
            if vm.account.isHW {
                lblJadeExtraNote.isHidden = false
            }
        case .remove:
            btnLearnMore.isHidden = true
        }
    }

    func setStyle() {
        cardView.layer.cornerRadius = 10
        cardView.borderWidth = 1.0
        cardView.borderColor = .white.withAlphaComponent(0.05)
        lblTitle.setStyle(.titleCard)
        lblHint.setStyle(.txtCard)
        btnLearnMore.setStyle(.inline)
        btnMain.setStyle(.primary)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss(_ action: LTShortcutUserAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            DispatchQueue.main.async {
                AppNotifications.shared.requestRemoteNotificationPermissions(application: UIApplication.shared) {
                    DispatchQueue.main.async {
                        self.dismiss(animated: false, completion: {
                            self.delegate?.onTap(action)
                        })
                    }
                }
            }
        })
    }

    @IBAction func btnLearnMore(_ sender: Any) {
        if let url = URL(string: vm.linkMore) {
            if UIApplication.shared.canOpenURL(url) {
                SafeNavigationManager.shared.navigate(url)
            }
        }
    }
    @IBAction func btnMain(_ sender: Any) {
        self.dismiss(self.vm.action == .remove ? .remove : .done)
    }
}
