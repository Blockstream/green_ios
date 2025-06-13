import UIKit
import core

class V5ViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnGetStarted: UIButton!
    @IBOutlet weak var animateView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        lblTitle.text = "id_green_is_now_the_blockstream_app".localized
        lblHint.text = "id_weve_redesigned_the_app_to_make".localized
        btnGetStarted.setTitle("id_get_started".localized, for: .normal)
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txtCard)
        btnGetStarted.setStyle(.primary)
        UserDefaults.standard.set(true, forKey: AppStorageConstants.v5Triggered.rawValue)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let riveView = RiveModel.animationV5.createRiveView()
        riveView.frame = CGRect(x: 0.0, y: 0.0, width: animateView.frame.width, height: animateView.frame.height)
        animateView.addSubview(riveView)
    }
    @IBAction func btnGetStarted(_ sender: Any) {
        AccountNavigator.navFirstPage()
    }
}
