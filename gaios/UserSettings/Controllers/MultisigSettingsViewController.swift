import UIKit
import PromiseKit

class MultisigSettingsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var session: SessionManager!
    private var viewModel: MultisigSettingsViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = session.gdkNetwork.chain
        view.accessibilityIdentifier = AccessibilityIdentifiers.SettingsScreen.view

        AnalyticsManager.shared.recordView(.walletSettings, sgmt: AnalyticsManager.shared.sessSgmt(AccountsRepository.shared.current))

        initViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.load()
    }

    func initViewModel() {
        viewModel = MultisigSettingsViewModel(session: session)
        viewModel.reloadTableView = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
        viewModel.error = { [weak self] text in
            DispatchQueue.main.async {
                self?.showError(text)
            }
        }
    }

    @objc func close() {
        dismiss(animated: true, completion: nil)
    }
}

extension MultisigSettingsViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.getCellModels().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let vm = viewModel.getCellModel(at: indexPath)
        if let cell = tableView.dequeueReusableCell(withIdentifier: MultisigSettingsCell.identifier) as? MultisigSettingsCell {
            cell.viewModel = vm
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = viewModel.getCellModel(at: indexPath)
        switch item?.type {
        case .WatchOnly:
            openWatchOnly()
        case .TwoFactorAuthentication:
            openTwoFactorAuthentication()
        case .Pgp:
            openPgp()
        default:
            break
        }
    }
}

extension MultisigSettingsViewController {
    func openWatchOnly() {
        let storyboard = UIStoryboard(name: "Shared", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogWatchOnlySetUpViewController") as? DialogWatchOnlySetUpViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            vc.session = session
            present(vc, animated: false, completion: nil)
        }
    }

    func openTwoFactorAuthentication() {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TwoFactorAuthenticationViewController") as? TwoFactorAuthenticationViewController {
            navigationController?.pushViewController(vc, animated: true)
            vc.delegate = self
        }
    }

    func openPgp() {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "PgpViewController") as? PgpViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension MultisigSettingsViewController: DialogWatchOnlySetUpViewControllerDelegate {
    func watchOnlyDidUpdate(_ action: WatchOnlySetUpAction) {
        switch action {
        case .save, .delete:
            viewModel.load()
        default:
            break
        }
    }
}

extension MultisigSettingsViewController: TwoFactorAuthenticationViewControllerDelegate {
    func userLogout() {}
}
