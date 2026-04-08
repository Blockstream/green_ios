import Foundation
import UIKit
import core
import gdk

class LTCreateViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblDescription: UILabel!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var btnLearnMore: UIButton!
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
        lblTitle.text = "Lightning is in Beta".localized
        lblDescription.text = "While your underlying funds remain secure, you may experience occasional payment failures or temporary delays when accessing your balance during network updates.\n\nWe recommend only using funds that you don't need immediate, urgent access to.".localized
        btnNext.setTitle("Enable Lightning".localized, for: .normal)
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblDescription.setStyle(.txtSectionHeader)
        btnNext.setStyle(.primary)
        btnLearnMore.setStyle(.underline(txt: "id_learn_more".localized, color: UIColor.gAccent()))
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

    @IBAction func tapLearnMore(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.understandingLightningSupport)
    }

    func enableLightning() async {
        startLoader(message: "Enabling...")
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
            showError(error)
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
