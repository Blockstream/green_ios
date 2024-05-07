import Foundation
import UIKit

class QRUnlockJadePinInfoViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var lblInfo1: UILabel!
    @IBOutlet weak var lblInfo2: UILabel!
    @IBOutlet weak var lblInfo3: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()
        loadNavigationBtns()
    }

    func setContent() {
        title = "Setp Pin via QR"
        lblTitle.text = "Set your PIN via QR on your Jade to get started".localized
        lblHint.text = "This allows you to sign transactions and validate addresses using Jade's camera".localized
        btnNext.setTitle("Start QR Unlock".localized, for: .normal)
        lblInfo1.text = "Utitlize a fully air-gapped workflow, no USB or Bluetooth required"
        lblInfo2.text = "Keep your keys encrypted on Jade, easily accessible with PIN"
        lblInfo3.text = "Not vulnerable to brute-force attacks due to Jade’s unique security model"
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblHint.font = UIFont.systemFont(ofSize: 20.0, weight: .regular)
        lblHint.textColor = .gW60()
        btnNext.setStyle(.primary)
        [lblInfo1, lblInfo2, lblInfo3].forEach {
            $0?.setStyle(.txt)
        }
    }

    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        settingsBtn.tintColor = UIColor.gGreenMatrix()
        settingsBtn.setTitle("id_setup_guide".localized, for: .normal)
        settingsBtn.addTarget(self, action: #selector(setupBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsBtn)
    }

    @objc func setupBtnTapped() {
        let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = hwFlow.instantiateViewController(withIdentifier: "SetupJadeViewController") as? SetupJadeViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func btnNext(_ sender: Any) {

        let storyboard = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "QRScanOnJadeViewController") as? QRScanOnJadeViewController {
            vc.vm = QRScanOnJadeViewModel(scope: .oracle)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
