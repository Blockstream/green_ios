import UIKit

import gdk

enum QRUnlockSelectAccountSection: Int, CaseIterable {
    case asset
    case policy
    case footer
}

class QRUnlockSelectAccountViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnAdvanced: UIButton!

    private var headerH: CGFloat = 54.0
    private var footerH: CGFloat = 54.0

    var viewModel: QRUnlockSelectAccountViewModel!

    var visibilityState: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        ["PolicyCell", "AssetSelectCell" ].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }

        setContent()
        setStyle()
    }

    @MainActor
    func reloadSections(_ sections: [QRUnlockSelectAccountSection], animated: Bool) {
        if animated {
            tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
        } else {
            UIView.performWithoutAnimation {
                tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
    }

    func setContent() {
        title = "Select Your Account Type".localized
        btnAdvanced.setTitle( visibilityState ? "id_hide_advanced_options".localized : "id_show_advanced_options".localized, for: .normal)
    }

    func setStyle() {
    }

    @IBAction func btnAdvanced(_ sender: Any) {
        viewModel?.showAll.toggle()
        reloadSections([.policy], animated: true)
        visibilityState = !visibilityState
        setContent()
    }
}

extension QRUnlockSelectAccountViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return QRUnlockSelectAccountSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch QRUnlockSelectAccountSection(rawValue: section) {
        case .asset:
            return 1
        case .policy:
            return viewModel?.getPolicyCellModels().count ?? 0
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        btnAdvanced.isHidden = !viewModel.isAdvancedEnable()

        switch QRUnlockSelectAccountSection(rawValue: indexPath.section) {
        case .asset:
            if let cell = tableView.dequeueReusableCell(withIdentifier: AssetSelectCell.identifier, for: indexPath) as? AssetSelectCell,
               let model = viewModel?.assetCellModel {
                cell.configure(model: model, showEditIcon: true)
                cell.selectionStyle = .none
                return cell
            }
        case .policy:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PolicyCell.identifier, for: indexPath) as? PolicyCell,
               let model = viewModel {
                cell.configure(model: model.getPolicyCellModels()[indexPath.row])
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch QRUnlockSelectAccountSection(rawValue: section) {
        default:
            return headerH
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch QRUnlockSelectAccountSection(rawValue: section) {
        case .footer:
            return 100.0
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        switch QRUnlockSelectAccountSection(rawValue: indexPath.section) {
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        switch QRUnlockSelectAccountSection(rawValue: section) {
        case .asset:
            return headerView( "Asset" )
        case .policy:
            return headerView( "Security Policy" )
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch QRUnlockSelectAccountSection(rawValue: section) {
        default:
            return footerView()
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch QRUnlockSelectAccountSection(rawValue: indexPath.section) {
        default:
            return indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch QRUnlockSelectAccountSection(rawValue: indexPath.section) {
        case .asset:
            break
//            let storyboard = UIStoryboard(name: "Utility", bundle: nil)
//            if let vc = storyboard.instantiateViewController(withIdentifier: "AssetSelectViewController") as? AssetSelectViewController {
//                let assetIds = WalletManager.current?.registry.all.map { ($0.assetId, Int64(0)) }
//                let dict = Dictionary(uniqueKeysWithValues: assetIds ?? [])
//                let list = AssetAmountList(dict)
//                vc.viewModel = AssetSelectViewModel(assets: list, enableAnyAsset: true)
//                vc.delegate = self
//                navigationController?.pushViewController(vc, animated: true)
//            }
        case .policy:
            let storyboard = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "QRScanOnJadeViewController") as? QRScanOnJadeViewController {
                vc.vm = QRScanOnJadeViewModel(scope: .oracle)
                navigationController?.pushViewController(vc, animated: true)
            }
        default:
            break
        }
    }

}

extension QRUnlockSelectAccountViewController {

    func headerView(_ txt: String) -> UIView {

        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = UIColor.clear
        let title = UILabel(frame: .zero)
        title.font = .systemFont(ofSize: 14.0, weight: .semibold)
        title.text = txt
        title.textColor = .white.withAlphaComponent(0.6)
        title.numberOfLines = 1

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor, constant: 10.0),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 30),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: 30)
        ])

        return section
    }

    func footerView() -> UIView {
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 1.0))
        section.backgroundColor = .clear
        return section
    }
}

extension QRUnlockSelectAccountViewController: AssetSelectViewControllerDelegate {
    func didSelectAsset(_ assetId: String) {
        viewModel?.asset = assetId
        reloadSections([.asset, .policy], animated: true)
    }

    func didSelectAnyAsset() {
        // handle any asset case
        print("didSelectAnyAsset")
        viewModel?.asset = AssetInfo.lbtcId
        reloadSections([.asset, .policy], animated: true)
    }
}
