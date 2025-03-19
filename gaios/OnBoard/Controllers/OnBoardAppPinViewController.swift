import UIKit

class OnBoardAppPinViewController: UIViewController {

    @IBOutlet weak var lblHead: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint1: UILabel!
    @IBOutlet weak var lblHint2: UILabel!
    @IBOutlet weak var btnPin: UIButton!
    @IBOutlet weak var btnMore: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
    }

    func setContent() {
        lblHead.text = "PIN".localized
        lblTitle.text = "Enable PIN to protect your wallet".localized
        lblHint1.text = "This ensures a secure way to access your wallet.".localized
        lblHint2.text = "Warning: If you forget your PIN and have not enabled biometrics or a recovery method, you will lose access to funds.".localized
        btnPin.setTitle("Setup PIN".localized, for: .normal)
        btnMore.setTitle("Learn more".localized, for: .normal)
    }

    func setStyle() {
        lblHead.setStyle(.txtCard)
        lblTitle.setStyle(.subTitle)
        [lblHint1, lblHint2].forEach {
            $0?.setStyle(.txtCard)
        }
        btnPin.setStyle(.primary)
        btnMore.setStyle(.outlined)
    }

    @IBAction func btnPin(_ sender: Any) {

    }

    @IBAction func btnMore(_ sender: Any) {

    }
}
