import UIKit

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

            print(riveView.frame)
            self.animateView.addSubview(riveView)
        }
    }
    func setContent() {
        lblTitle.text = "Great! You successfully backed up your recovery phrase.".localized
        lblHint.text = "Keep your recovery phrase fully offline and stored somewhere secret. Anyone with a copy of these words can steal your funds.".localized
        btnNext.setTitle("id_done".localized, for: .normal)
    }
    func setStyle() {
        lblTitle.setStyle(.subTitle24)
        lblHint.setStyle(.txtCard)
        btnNext.setStyle(.primary)
    }
    @IBAction func btnNext(_ sender: Any) {
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
