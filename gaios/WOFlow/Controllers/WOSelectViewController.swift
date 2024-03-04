import UIKit
import gdk

class WOSelectViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    let viewModel = WOViewModel()
    var networks = [NetworkSecurityCase]()
    var selectSS = true

    override func viewDidLoad() {
        super.viewDidLoad()

        ["WOTypeCell",].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
        setContent()
        setStyle()
    }

    func setContent() {
        lblTitle.text = "id_select_watchonly_type".localized
        lblHint.text = "id_choose_the_security_policy_that".localized
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblHint.setStyle(.txt)
    }
}

extension WOSelectViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.types.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: WOTypeCell.identifier, for: indexPath) as? WOTypeCell {
            let model = viewModel.types[indexPath.row]
            cell.configure(model)
            cell.selectionStyle = .none
            return cell
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0: // SS
            selectNetwork(singlesig: true)
        case 1: // MS
            selectNetwork(singlesig: false)
        default:
            break
        }
    }

    func login(for network: NetworkSecurityCase) {
        let hwFlow = UIStoryboard(name: "WOFlow", bundle: nil)
        if network.singlesig {
            if let vc = hwFlow.instantiateViewController(withIdentifier: "WODetailsViewController") as? WODetailsViewController {
                vc.network = network
                navigationController?.pushViewController(vc, animated: true)
            }
        } else {
            if let vc = hwFlow.instantiateViewController(withIdentifier: "WOSetupViewController") as? WOSetupViewController {
                vc.network = network
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}

extension WOSelectViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func getNetworks(singlesig: Bool, testnet: Bool) -> [NetworkSecurityCase] {
        if testnet {
            return singlesig ? [.testnetSS, .testnetLiquidSS] : [.testnetMS, .testnetLiquidMS]
        } else {
            return singlesig ? [ .bitcoinSS, .liquidSS] : [.bitcoinMS, .liquidMS]
        }
    }

    func selectNetwork(singlesig: Bool) {
        let testnet = OnBoardManager.shared.chainType == .testnet
        networks = getNetworks(singlesig: singlesig, testnet: testnet)
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            let cells = networks.map { DialogListCellModel(type: .list,
                                                           icon: nil,
                                                           title: $0.name()) }
            vc.viewModel = DialogListViewModel(title: "Select Network", type: .watchOnlyPrefs, items: cells)
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func didSelectIndex(_ index: Int, with type: DialogType) {
        login(for: networks[index])
    }
}
