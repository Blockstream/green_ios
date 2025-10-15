import Foundation
import UIKit
import core

protocol LTRemoveShortcutViewControllerDelegate: AnyObject {
    func onCancel()
    func onRemove(_ index: String?)
}

enum LTRemoveShortcut {
    case cancel
    case remove
}

class LTRemoveShortcutViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnRemove: UIButton!

    weak var delegate: LTRemoveShortcutViewControllerDelegate?

    var index: String?

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
        lblTitle.text = "id_payments_will_fail".localized
        lblHint.text = "id_you_will_stop_receiving_push".localized
        btnCancel.setTitle("id_cancel".localized, for: .normal)
        btnRemove.setTitle("id_remove_lightning_shortcut".localized, for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.alert)
        
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txt)
        btnCancel.setStyle(.outlinedWhite)
        btnRemove.setStyle(.destructive)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss(_ action: LTRemoveShortcut) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: { [weak self] () in
                switch action {
                case .cancel:
                    self?.delegate?.onCancel()
                case .remove:
                    self?.delegate?.onRemove(self?.index)
                }
            })
        })
    }

    @IBAction func btnCancel(_ sender: Any) {
        dismiss(.cancel)
    }

    @IBAction func btnRemove(_ sender: Any) {
        dismiss(.remove)
    }
}
