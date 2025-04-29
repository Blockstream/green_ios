import UIKit

class BackupSuccessViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnNext: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        navigationItem.hidesBackButton = true
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
