import UIKit
import core

class HowToSecureViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnWatchOnly: UIButton!
    @IBOutlet weak var tableView: UITableView!

    static var flowType: OnBoardingFlowType = .add
    static var chainType: OnBoardingChainType = .mainnet

    var model = HowToSecureViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        tableView.register(UINib(nibName: "HowToSecureCell", bundle: nil), forCellReuseIdentifier: "HowToSecureCell")

//        AnalyticsManager.shared.recordView(.onBoardIntro)
    }

    @objc func back(sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    func setContent() {

        lblTitle.text = "id_how_do_you_want_to_secure_your".localized
        btnWatchOnly.setTitle("id_watchonly".localized, for: .normal)
    }

    func setStyle() {
        btnWatchOnly.setStyle(.outlinedWhite)
    }

    func selectNetwork() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "id_select_network".localized, type: .networkPrefs, items: NetworkPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func next() {
        let storyboard = UIStoryboard(name: "WOFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "WOSelectViewController")
        navigationController?.pushViewController(vc, animated: true)
        AnalyticsManager.shared.woWallet()
    }

    @IBAction func btnWatchOnly(_ sender: Any) {

        OnboardViewModel.flowType = .watchonly

        let testnetAvailable = AppSettings.shared.testnet
        if testnetAvailable {
            selectNetwork()
        } else {
            next()
        }
    }
}

extension HowToSecureViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch NetworkPrefs(rawValue: index) {
        case .mainnet:
            OnboardViewModel.chainType = .mainnet
            next()
        case .testnet:
            OnboardViewModel.chainType = .testnet
            next()
        case .none:
            break
        }
    }
}

extension HowToSecureViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return model.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if let cell = tableView.dequeueReusableCell(withIdentifier: "HowToSecureCell", for: indexPath) as? HowToSecureCell {
            cell.configure(model: model.items[indexPath.row])
            cell.selectionStyle = .none
            return cell
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let model = model.items[indexPath.row]

        switch model.type {
        case .sw:
            let onBFlow = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = onBFlow.instantiateViewController(withIdentifier: "StartOnBoardViewController") as? StartOnBoardViewController {
                navigationController?.pushViewController(vc, animated: true)
                AnalyticsManager.shared.addWallet()
            }
        case .hw:
            let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "WelcomeJadeViewController") as? WelcomeJadeViewController {
                navigationController?.pushViewController(vc, animated: true)
                AnalyticsManager.shared.hwwWallet()
            }
        }
    }
}
