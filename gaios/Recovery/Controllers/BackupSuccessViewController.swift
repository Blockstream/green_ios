import UIKit
import core
class BackupSuccessViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var animateView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        navigationItem.hidesBackButton = true
    }
    override func viewWillAppear(_ animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
            let riveView = RiveModel.animationCheckMark.createRiveView()
            riveView.frame = CGRect(x: 0.0, y: 0.0, width: self.animateView.frame.width, height: self.animateView.frame.height)
            self.animateView.addSubview(riveView)
        }
    }
    func setContent() {
        lblTitle.text = "id_great_you_successfully_backed".localized
        lblHint.text = "id_keep_your_recovery_phrase_fully".localized
        btnNext.setTitle("id_done".localized, for: .normal)
    }
    func setStyle() {
        lblTitle.setStyle(.subTitle24)
        lblHint.setStyle(.txtCard)
        btnNext.setStyle(.primary)
    }
    @IBAction func btnNext(_ sender: Any) {
        AnalyticsManager.shared.backupManual(account: AccountsRepository.shared.current)
        let originReceive = navigationController?.viewControllers.filter { $0 is ReceiveViewController }.first
        let originBuy = navigationController?.viewControllers.filter { $0 is BuyBTCViewController }.first
        if originReceive != nil {
            navigationController?.popToViewController(ofClass: ReceiveViewController.self)
        } else if originBuy != nil {
            navigationController?.popToViewController(ofClass: BuyBTCViewController.self)
        } else {
            navigationController?.popToRootViewController(animated: true)
        }
    }
}
