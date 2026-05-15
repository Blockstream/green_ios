import Foundation
import UIKit
import core
import gdk
import RiveRuntime
import hw

class LTCreateViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblDescription: UILabel!
    @IBOutlet weak var animateView: UIView!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var btnLearnMore: UIButton!
    @IBOutlet weak var icInfo1: UIImageView!
    @IBOutlet weak var icInfo2: UIImageView!
    @IBOutlet weak var icInfo3: UIImageView!
    @IBOutlet weak var lblInfo1: UILabel!
    @IBOutlet weak var lblInfo2: UILabel!
    @IBOutlet weak var lblInfo3: UILabel!

    var viewModel: LTCreateViewModel!
    private var riveView: RiveView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        setupAlertCard()
        setupRiveView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    func setContent() {
        if (viewModel.isHW) {
            lblTitle.text = "Get More Out of Jade".localized
            lblDescription.text = "Unlock Lightning for this wallet.".localized
        } else {
            lblTitle.text = "Lightning Network".localized
            lblDescription.text = "A scaling solution for faster, cheaper Bitcoin payments.".localized
        }
      
        btnNext.setTitle("Enable Lightning".localized, for: .normal)
        
        icInfo1.image = UIImage(named: "ic_sec_lev_coins")?.maskWithColor(color: .lightGray)
        icInfo2.image = UIImage(named: "ic_sec_lev_light")?.maskWithColor(color: .lightGray)
        icInfo3.image = UIImage(named: "ic_sec_lev_globe")?.maskWithColor(color: .lightGray)
        lblInfo1.text = "Low Fees".localized
        lblInfo2.text = "Instant Transactions".localized
        lblInfo3.text = "Global, Permissionless Payments".localized
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblTitle.textAlignment = .center

        lblDescription.setStyle(.txtSectionHeader)
        lblDescription.textAlignment = .center
        
        lblInfo1.setStyle(.txt)
        lblInfo2.setStyle(.txt)
        lblInfo3.setStyle(.txt)

        btnNext.setStyle(.primary)
        btnLearnMore.setStyle(.underline(txt: "id_learn_more".localized, color: UIColor.gAccent()))
    }

    func setupAlertCard() {
        let nib = UINib(nibName: "AlertCardCell", bundle: nil)
        guard let cell = nib.instantiate(withOwner: nil, options: nil).first as? AlertCardCell else { return }
        cell.configure(AlertCardCellModel(type: .lightningBeta), onLeft: nil, onRight: nil, onDismiss: nil)
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(cell)
        
        NSLayoutConstraint.activate([
            cell.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -5),
            cell.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 5),
            cell.bottomAnchor.constraint(equalTo: btnNext.topAnchor, constant: -12),
            cell.contentView.topAnchor.constraint(equalTo: cell.topAnchor),
            cell.contentView.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
            cell.contentView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            cell.contentView.trailingAnchor.constraint(equalTo: cell.trailingAnchor)
        ])
    }
    
    func setupRiveView() {
        let view = RiveModel.lightningSuccess.createRiveView()
        view.frame = CGRect(x: 0.0, y: 0.0, width: animateView.frame.width, height: animateView.frame.height)
        animateView.addSubview(view)
        riveView = view
    }

    @IBAction func tapNext(_ sender: Any) {
        if viewModel.isHW {
            presentConnectJadeViewController()
            return
        }
        Task { [weak self] in
            await self?.enableLightning()
        }
    }

    @IBAction func tapLearnMore(_ sender: Any) {
        let url = viewModel.isHW ? ExternalUrls.lightningJadeHelp : ExternalUrls.understandingLightningSupport
        SafeNavigationManager.shared.navigate(url)
    }
    

    func enableLightning() async {
        startLoader(message: "Enabling Lightning...")
        let task = Task.detached { [weak self] in
            try await self?.viewModel.enableLightning()
        }
        switch await task.result {
        case .success:
            stopLoader()
            DropAlert().success(message: "Lightning enabled")
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: EventType.newSubaccount.rawValue), object: nil, userInfo: nil)
            if viewModel.isHW {
                pushLTExportJadeViewController()
            } else {
                navigationController?.popViewController(animated: true)
            }
        case .failure(let error):
            stopLoader()
            showError(error)
        }
    }

    @MainActor
    func pushLTExportJadeViewController() {
        let storyboard = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LTExportJadeViewController") as? LTExportJadeViewController {
            vc.viewModel = LTExportJadeViewModel(wallet: viewModel.wallet)
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @MainActor
    func presentConnectJadeViewController() {
        let storyboard = UIStoryboard(name: "HWDialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "HWDialogConnectViewController") as? HWDialogConnectViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
}

extension LTCreateViewController: LTExportJadeViewControllerDelegate {
    func didExportedWallet() {
        DropAlert().success(message: "Lightning enabled")
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: EventType.newSubaccount.rawValue), object: nil, userInfo: nil)
        navigationController?.popViewController(animated: true)
    }
}

extension LTCreateViewController: HWDialogConnectViewControllerDelegate {
    func connected() {}

    func logged() {
        pushLTExportJadeViewController()
    }

    func cancel() {}

    func failure(err: Error) {
        showError(err)
    }
}
