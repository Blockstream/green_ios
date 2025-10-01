import Foundation
import UIKit
import core
import gdk
import BreezSDK

class LTCreateViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblSubtitle: UILabel!
    @IBOutlet weak var lblDescription: UILabel!
    @IBOutlet weak var btnNext: UIButton!

    var viewModel: LTCreateViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    func setContent() {
        lblTitle.text = "id_lightning_network".localized
        lblSubtitle.text = "id_lightning_network_not_enabled".localized
        lblDescription.text = "Experimental Lightning support is currently unavailable to new users.".localized
        btnNext.setTitle("Enable Lightning".localized, for: .normal)
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblSubtitle.setStyle(.txtBigger)
        lblDescription.setStyle(.txtSectionHeader)
        btnNext.setStyle(.primary)
    }

    @IBAction func tapNext(_ sender: Any) {
        // if jade: push export lightning for hardware wallet
        if viewModel.isHW {
            pushLTExportJadeViewController()
            return
        }
        // derive lightning for software wallet
        Task { [weak self] in
            await self?.enableLightning()
        }
    }

    func enableLightning() async {
        startLoader(message: "Restoring...")
        let task = Task.detached { [weak self] in
            try await self?.viewModel.enableLightning()
        }
        switch await task.result {
        case .success:
            stopLoader()
            DropAlert().success(message: "Lightning enabled successfully")
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: EventType.newSubaccount.rawValue), object: nil, userInfo: nil)
            navigationController?.popViewController(animated: true)
        case .failure(let error):
            stopLoader()
            switch error as? BreezSDK.ConnectError {
            case .RestoreOnly(let message):
                showError("Experimental Lightning support is currently unavailable to new users.".localized)
            default:
                showError(error)
            }
        }
    }

    @MainActor
    func pushLTExportJadeViewController() {
        let storyboard = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LTExportJadeViewController") as? LTExportJadeViewController {
            vc.viewModel = LTExportJadeViewModel()
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension LTCreateViewController: LTExportJadeViewControllerDelegate {
    func didExportedWallet() {
        navigationController?.popViewController(animated: true)
    }
}
