import Foundation
import UIKit
import core
import gdk
import hw

class JadeBoltzSwapViewController: UIViewController {
    @IBOutlet weak var viewEnabled: UIView!
    @IBOutlet weak var lblTitleEnabled: UILabel!
    @IBOutlet weak var lblHintEnabled: UILabel!
    @IBOutlet weak var imgEnabled: UIImageView!
    @IBOutlet weak var viewDisabled: UIView!
    @IBOutlet weak var lblTitleDisabled: UILabel!
    @IBOutlet weak var lblHintDisabled: UILabel!
    @IBOutlet weak var imgDisabled: UIImageView!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var btnNotNow: UIButton!
    @IBOutlet weak var btnLearnMore: UIButton!
    @IBOutlet weak var lblDisableWarn: UILabel!
    
    let viewModel: JadeBoltzSwapViewModel

    init?(coder: NSCoder, viewModel: JadeBoltzSwapViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reload()
    }
    func setContent() {
        reload()
    }
    func setStyle() {
        [lblHintEnabled, lblHintDisabled, lblDisableWarn].forEach {
            $0.setStyle(.txtCard)
        }
        btnNotNow.setStyle(.outlined)
        btnLearnMore.setStyle(.underline(txt: "Learn More".localized, color: UIColor.gAccent()))
    }
    func reload() {
        lblDisableWarn.text = "You cannot disable while a swap is in progress.".localized
        lblDisableWarn.isHidden = true
        let existBoltzKey = viewModel.existBoltzKey()
        if existBoltzKey {
            reloadEnabledSwaps()
        } else {
            reloadDisabledSwaps()
        }
        viewEnabled.isHidden = !existBoltzKey
        viewDisabled.isHidden = existBoltzKey
    }
    func reloadEnabledSwaps() {
        lblTitleEnabled.text = "Swaps Enabled!".localized
        lblHintEnabled.text = "Swaps are enabled on this phone. If you switch phones or reinstall the app, you’ll need to set it up again with Jade.".localized
        btnNext.setTitle("Remove From This Phone".localized, for: .normal)
        btnNotNow.setTitle("Not Now".localized, for: .normal)
        btnNotNow.isHidden = true
        lblTitleEnabled.setStyle(.txtBigger)
        Task {
            let hasSwap =  await viewModel.existPendingSwap()
            await MainActor.run {
                btnNext.isEnabled = !hasSwap
                btnNext.setStyle(!hasSwap ? .outlined : .primaryDisabled)
                lblDisableWarn.isHidden = !hasSwap
            }
        }
    }
    func reloadDisabledSwaps() {
        lblTitleDisabled.text = "Get More Out of Jade".localized
        lblHintDisabled.text = "Unlock swaps for this wallet. Jade remains necessary for signing".localized
        btnNext.setTitle("Enable Swaps".localized, for: .normal)
        btnNotNow.setTitle("Not Now".localized, for: .normal)
        btnNext.setStyle(.primary)
        btnNotNow.isHidden = false
        lblTitleDisabled.setStyle(.subTitle24)
        lblDisableWarn.isHidden = true
    }
    func removeBoltzKey() async {
        startLoader()
        let task = Task.detached { [weak self] in
            try self?.viewModel.removeBoltzKey()
            try await self?.viewModel.disconnectBoltz()
        }
        switch await task.result {
        case .success:
            self.stopLoader()
            self.reload()
            DropAlert().success(message: "Swaps are disabled")
            self.navigationController?.popToRootViewController(animated: true)
        case .failure(let err):
            self.stopLoader()
            self.showError(err)
        }
    }

    func jadeBoltzExportViewController() -> JadeBoltzExportViewController {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        let viewModel = JadeBoltzExportViewModel(wallet: viewModel.wm, mainAccount: viewModel.mainAccount)
        let vc = storyboard.instantiateViewController(identifier: "JadeBoltzExportViewController") { coder in
            JadeBoltzExportViewController(coder: coder, viewModel: viewModel)
        }
        vc.delegate = self
        return vc
    }

    @IBAction func btnNext(_ sender: Any) {
        // on disable: remove the boltz key
        if viewModel.existBoltzKey() {
            Task { [weak self] in
                await self?.removeBoltzKey()
            }
            return
        }
        // on enable: send to export key
        AnalyticsManager.shared.swapSetup(account: AccountsRepository.shared.current)
        let vc = jadeBoltzExportViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    @IBAction func btnNotNow(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    @IBAction func btnLearnMore(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.swapJadeGetMoreSettings)
    }
}
extension JadeBoltzSwapViewController: JadeBoltzExportViewControllerDelegate {
    func onExportSucceed() {
        navigationController?.popToRootViewController(animated: true)
    }
}
