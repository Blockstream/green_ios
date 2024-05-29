import Foundation
import UIKit

protocol ReEnable2faSuccessViewControllerDelegate: AnyObject {
    func onDone()
}

class ReEnable2faSuccessViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnDone: UIButton!

    weak var delegate: ReEnable2faSuccessViewControllerDelegate!

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
        lblTitle.text = "2FA Reactivated!".localized
        lblHint.text = "Your coins are protected by 2FA again!".localized
        btnDone.setTitle("id_done".localized, for: .normal)
    }

    func setStyle() {
        cardView.layer.cornerRadius = 10
        lblTitle.setStyle(.subTitle)
        btnDone.setStyle(.primary)
        lblHint.setStyle(.txtCard)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: completion)
        })
    }

    @IBAction func btnDone(_ sender: Any) {
        dismiss() {
            self.delegate?.onDone()
        }
    }
}
