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
        lblHead.text = "id_pin".localized
        lblTitle.text = "id_enable_pin_to_protect_your".localized
        lblHint1.text = "id_this_ensures_a_secure_way_to".localized
        lblHint2.text = "id_warning_if_you_forget_your_pin".localized
        btnPin.setTitle("id_set_up_pin".localized, for: .normal)
        btnMore.setTitle("id_learn_more".localized, for: .normal)
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
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SetPinViewController") as? SetPinViewController {
            vc.pinFlow = OnboardViewModel.flowType == .add ? .create : .restore
            vc.viewModel = OnboardViewModel()
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func btnMore(_ sender: Any) {

    }
}
