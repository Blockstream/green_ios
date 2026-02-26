import Foundation
import gdk
import UIKit
import core
protocol DialogSwapJadeEnabledViewControllerDelegate: AnyObject {
    func onSwapEnabledDone()
}

class DialogSwapJadeEnabledViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnDone: UIButton!

    weak var delegate: DialogSwapJadeEnabledViewControllerDelegate!

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
        lblTitle.text = "Swaps Enabled!".localized
        lblHint.text = "You can now swap with Jade. If you move to another phone, you must pair with Jade again.".localized
        btnDone.setTitle("id_done".localized, for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.alert)
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txtCard)
        btnDone.setStyle(.primary)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    func dismiss() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: { [weak self] in
                self?.delegate?.onSwapEnabledDone()
            })
        })
    }
    @IBAction func btnDone(_ sender: Any) {
        AnalyticsManager.shared.swapEnable(account: AccountsRepository.shared.current)
        self.dismiss()
    }
}
