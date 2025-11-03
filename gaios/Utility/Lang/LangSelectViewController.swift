import UIKit
import core

protocol LangSelectViewControllerDelegate: AnyObject {
    func didUpdateLang()
}

enum LangSelectSection: Int, CaseIterable {
    case reset
    case langs
}

class LangSelectViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var tableView: UITableView!

    var viewModel = LangSelectViewModel()
    var delegate: LangSelectViewControllerDelegate?

    lazy var blurredView: UIView = {
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

        register()
        setContent()
        setStyle()

        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)

        view.alpha = 0.0
        anchorBottom.constant = -cardView.frame.size.height

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
            swipeDown.direction = .down
            self.view.addGestureRecognizer(swipeDown)
        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTap))
            tappableBg.addGestureRecognizer(tapToClose)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    func setContent() {
        lblTitle.text = "id_language".localized
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.txtBigger)
    }

    func register() {
        ["LangCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }

    func dismiss() {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in

            self.dismiss(animated: false, completion: nil)
        })
    }

    @objc func didTap(gesture: UIGestureRecognizer) {
        dismiss()
    }

    @objc func didSwipe(gesture: UIGestureRecognizer) {

        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                dismiss()
            default:
                break
            }
        }
    }

    func reInit() {
        Task {
            if AccountsRepository.shared.current == nil {
                AccountNavigator.navLogout(accountId: nil)
                return
            }
            if AppSettings.shared.gdkSettings?.tor ?? false {
                self.startLoader(message: "id_logging_out".localized)
            }
            Task {
                let account = AccountsRepository.shared.current
                if account?.isHW ?? false {
                    try? await BleHwManager.shared.disconnect()
                }
                await WalletManager.current?.disconnect()
                WalletsRepository.shared.delete(for: account?.id ?? "")
                AccountNavigator.navLogout(accountId: nil)
                self.stopLoader()
            }

        }
    }

    func showChangeLangAlert(_ idx: Int) {
        if let newLang = viewModel.newLang(idx) {
            let alert = UIAlertController(title: "Change Language to \(newLang.name)".localized, message: "id_the_app_will_be_restarted".localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "id_ok".localized, style: .default, handler: { [weak self] _ in
                self?.viewModel.update(idx)
                self?.tableView.reloadData {
                    self?.reInit()
                }
            }))
            present(alert, animated: true, completion: nil)
        }
    }

    func showResetToSystemLanguage() {
        let alert = UIAlertController(title: "id_reset_language_to_system_default".localized, message: "id_the_app_will_be_restarted".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "id_ok".localized, style: .default, handler: { [weak self] _ in
            self?.viewModel.resetToSystemLanguage()
            self?.tableView.reloadData {
                self?.reInit()
            }
        }))
        present(alert, animated: true, completion: nil)
    }
}

extension LangSelectViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return LangSelectSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case LangSelectSection.reset.rawValue:
            return 1
        case LangSelectSection.langs.rawValue:
            return viewModel.langList.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch indexPath.section {
        case LangSelectSection.reset.rawValue:
            let model = LangCellModel(title: "id_reset_to_system_default".localized, hint: "", isCurrent: false)
            if let cell = tableView.dequeueReusableCell(withIdentifier: LangCell.identifier, for: indexPath) as? LangCell {
                cell.configure(model)
                cell.selectionStyle = .none
                return cell
            }
        case LangSelectSection.langs.rawValue:
            let lang = viewModel.langList[indexPath.row]
            let model = LangCellModel(title: lang.name, hint: "", isCurrent: lang.code == viewModel.cLang.code)
            if let cell = tableView.dequeueReusableCell(withIdentifier: LangCell.identifier, for: indexPath) as? LangCell {
                cell.configure(model)
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return indexPath
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case LangSelectSection.reset.rawValue:
            showResetToSystemLanguage()
        case LangSelectSection.langs.rawValue:
            showChangeLangAlert(indexPath.row)
        default:
            break
        }
    }
}
