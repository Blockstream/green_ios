import Foundation
import UIKit

protocol LTShortcutViewControllerDelegate: AnyObject {
    func onTap(_ action: LTShortcutUserAction)
}

enum LTShortcutUserAction {
    case learnMore
    case add
    case remove
    case later
}

class LTShortcutViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var btnLearnMore: UIButton!
    @IBOutlet weak var btnMain: UIButton!
    @IBOutlet weak var btnLater: UIButton!
    
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
        btnLater.setTitle(vm.btnLater, for: .normal)
        
        switch vm.action {
        case .addFromAccount:
            btnLater.isHidden = false
            DrawerAnimationManager.shared.accountId = vm.account.id
            btnLater.setTitle(vm.btnCancel, for: .normal)
        case .addFromCreate:
            DrawerAnimationManager.shared.accountId = vm.account.id
            btnLater.isHidden = false
            btnLater.setTitle(vm.account.isHW ? vm.btnCancel : vm.btnLater , for: .normal)
        case .remove:
            btnLater.isHidden = true
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
        btnLater.setStyle(.inline)
        btnLater.setTitleColor(.white, for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss(_ action: LTShortcutUserAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                self.delegate?.onTap(action)
            })
        })
    }

    @IBAction func btnLearnMore(_ sender: Any) {
        if let url = URL(string: vm.linkMore) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        dismiss(.learnMore)
    }
    @IBAction func btnMain(_ sender: Any) {
        dismiss(vm.action == .remove ? .remove : .add)
    }
    @IBAction func btnLater(_ sender: Any) {
        dismiss(.later)
    }
}
