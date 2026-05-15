import Foundation
import UIKit
import core
import gdk

class LTSettingsDialogViewController: UIViewController {
    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblDetails: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!

    @IBOutlet weak var btnMnemonic: UIButton!
    @IBOutlet weak var btnDiagnostic: UIButton!
    @IBOutlet weak var btnDisable: UIButton!

    var viewModel: LTSettingsDialogViewModel!

    private var nodeCellTypes: [LTSettingsDialogCellType] { viewModel.cellTypes }

    private lazy var blurredView: UIView = {
        let containerView = UIView()
        let blurEffect = UIBlurEffect(style: .dark)
        let customBlurEffectView = CustomVisualEffectView(effect: blurEffect, intensity: 0.4)
        customBlurEffectView.frame = self.view.bounds
        let dimmedView = UIView()
        dimmedView.backgroundColor = .black.withAlphaComponent(0.3)
        dimmedView.frame = self.view.bounds
        containerView.addSubview(customBlurEffectView)
        containerView.addSubview(dimmedView)
        return containerView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        registerCells()

        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)

        view.alpha = 0.0
        anchorBottom.constant = -cardView.frame.size.height

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe(_:)))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)

        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTapBackground))
        tappableBg.addGestureRecognizer(tapToClose)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
        triggerReload()
    }

    func setContent() {
        lblTitle.text = "id_account_settings".localized
        lblDetails.text = "id_details".localized
        btnMnemonic.setTitle("id_show_recovery_phrase".localized, for: .normal)
        btnDiagnostic.setTitle("Generate Diagnostic Data".localized, for: .normal)
        btnDisable.setTitle("id_disable_lightning".localized, for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle)
        lblTitle.textAlignment = .center
        lblDetails.setStyle(.txtSectionHeader)
        [btnMnemonic, btnDiagnostic, btnDisable].forEach { $0.setStyle(.outlined) }
    }

    func registerCells() {
        tableView.register(
            UINib(nibName: "LTSettingDialogCell", bundle: nil),
            forCellReuseIdentifier: LTSettingDialogCell.identifier)
    }

    func triggerReload() {
        Task { [weak self] in
            await self?.viewModel.updateNodeInfo()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()
                self.tableViewHeight.constant = self.tableView.contentSize.height
            }
        }
    }

    @objc private func didSwipe(_ gesture: UIGestureRecognizer) {
        if let swipe = gesture as? UISwipeGestureRecognizer, swipe.direction == .down {
            dismissSheet()
        }
    }

    @objc private func didTapBackground() {
        dismissSheet()
    }

    @IBAction func btnMnemonic(_ sender: Any) {
        let nav = presentingViewController?.navigationController
                ?? (presentingViewController as? UINavigationController)
        dismissSheet { [weak nav] in
            guard let nav else { return }
            let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "ShowMnemonicsViewController") as? ShowMnemonicsViewController {
                vc.showBip85 = true
                nav.pushViewController(vc, animated: true)
            }
        }
    }
 
    @IBAction func btnDiagnostic(_ sender: Any) {
        Task { [weak self] in
            let data = await self?.viewModel.diagnosticData()
            await MainActor.run {
                UIPasteboard.general.string = data
                DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 1.0)
            }
        }
    }
 
    @IBAction func btnDisable(_ sender: Any) {
        let nav = presentingViewController?.navigationController
                ?? (presentingViewController as? UINavigationController)
        dismissSheet { [weak self, weak nav] in
            guard let self, let nav else { return }
            self.disableLightning(nav: nav)
        }
    }
   
    private func dismissSheet(completion: (() -> Void)? = nil) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
          self.view.alpha = 0.0
          self.view.layoutIfNeeded()
        }, completion: { _ in
          self.dismiss(animated: false, completion: completion)
        })
    }
   
    private func disableLightning(nav: UINavigationController) {
        Task {
            startLoader(message: "id_disabling".localized)
            let task = Task.detached { [weak self] in
                await self?.viewModel.disableLightning()
            }
            switch await task.result {
            case .success:
                stopLoader()
                DropAlert().success(message: "id_lightning_disabled_successfully".localized)
                NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: EventType.newSubaccount.rawValue),
                    object: nil, userInfo: nil)
                nav.popViewController(animated: true)
            case .failure(let error):
                stopLoader()
                showError(error)
            }
        }
    }
}

extension LTSettingsDialogViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        nodeCellTypes.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: LTSettingDialogCell.identifier) as? LTSettingDialogCell {
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            let cellType = nodeCellTypes[indexPath.row]
            let cellModel = viewModel.cellModelByType(cellType)
            cell.configure(model: cellModel)
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellType = nodeCellTypes[indexPath.row]
        if case .id = cellType {
            UIPasteboard.general.string = viewModel.id
            DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 1.0)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
