import UIKit
import core

class V5ViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnGetStarted: UIButton!
    @IBOutlet weak var animateView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        lblTitle.text = "Green is now the Blockstream app".localized
        lblHint.text = "We’ve redesigned the app to make it faster, easier, and even more secure. All your settings and funds are right where you left them.".localized
        btnGetStarted.setTitle("Get Started".localized, for: .normal)
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txtCard)
        btnGetStarted.setStyle(.primary)
        UserDefaults.standard.set(true, forKey: AppStorageConstants.v5Treiggered.rawValue)
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
