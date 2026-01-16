import UIKit
import core
import gdk

protocol AssetSelectViewControllerDelegate: AnyObject {
    func didSelectAnyOrAsset(_ ref: AnyOrAsset)
}

enum AnyOrAsset {
    case anyLiquid
    case anyAmp
    case asset(String)
    var assetId: String {
        switch self {
        case .anyLiquid, .anyAmp:
            return AssetInfo.lbtcId
        case .asset(let assetId):
            return assetId
        }
    }
}

class AssetSelectViewController: UIViewController {

    @IBOutlet weak var searchCard: UIView!
    @IBOutlet weak var btnSearch: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchField: UITextField!

    var viewModel: AssetSelectViewModel!
    weak var delegate: AssetSelectViewControllerDelegate?
    var dismissOnSelect = true

    override func viewDidLoad() {
        super.viewDidLoad()

        ["AssetSelectCell", "AnyAssetCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
        searchField.delegate = self
        title = "id_select_asset".localized
        setContent()
        setStyle()

        viewModel.reload = tableView.reloadData
    }

    func setContent() {
        searchField.attributedPlaceholder = NSAttributedString(string: "id_search_asset".localized, attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.4)])
    }

    func setStyle() {
        searchCard.setStyle(CardStyle.defaultStyle)
    }

    func didSelectAnyOrAsset(_ ref: AnyOrAsset) {
        if dismissOnSelect {
            dismiss(animated: true) { [weak self] in
                self?.delegate?.didSelectAnyOrAsset(ref)
            }
        } else {
            delegate?.didSelectAnyOrAsset(ref)
        }
    }
    @objc func triggerTextChange() {
        viewModel?.search(searchField.text ?? "")
        tableView.reloadData()
    }

    @IBAction func onEditingChange(_ sender: Any) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.triggerTextChange), object: nil)
        perform(#selector(self.triggerTextChange), with: nil, afterDelay: 0.5)
    }

    override func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        navigationController?.popViewController(animated: true)
        completion?()
    }
}

extension AssetSelectViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let cnt = viewModel?.assetSelectCellModelsFilter.count ?? 0
        return cnt + (viewModel?.anyAssetTypes().count ?? 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cnt = viewModel?.assetSelectCellModelsFilter.count ?? 0
        let anyAssetTypes: [AnyOrAsset] = viewModel.anyAssetTypes()
        if indexPath.row < cnt {
            if let cell = tableView.dequeueReusableCell(withIdentifier: AssetSelectCell.identifier, for: indexPath) as? AssetSelectCell {
                let model = viewModel.assetSelectCellModelsFilter[indexPath.row]
                cell.configure(model: model,
                               showEditIcon: false,
                               hasLwkSession: viewModel.hasLwkSession)
                cell.selectionStyle = .none
                cell.lblAsset.accessibilityIdentifier = AccessibilityIds.CommonElements.cellAssetSelect(indexPath.row)
                return cell
            }
        } else if indexPath.row == cnt {
            if let cell = tableView.dequeueReusableCell(withIdentifier: AnyAssetCell.identifier, for: indexPath) as? AnyAssetCell {
                cell.configure(anyAssetTypes[0])
                cell.selectionStyle = .none
                cell.lblAny.accessibilityIdentifier = AccessibilityIds.CommonElements.cellAssetSelect(indexPath.row)
                return cell
            }
        } else if indexPath.row == cnt+1 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: AnyAssetCell.identifier, for: indexPath) as? AnyAssetCell {
                cell.configure(anyAssetTypes[1])
                cell.selectionStyle = .none
                cell.lblAny.accessibilityIdentifier = AccessibilityIds.CommonElements.cellAssetSelect(indexPath.row)
                return cell
            }
        }
        if anyAssetTypes.count == 1 {
            if cnt == indexPath.row {
                if let cell = tableView.dequeueReusableCell(withIdentifier: AnyAssetCell.identifier, for: indexPath) as? AnyAssetCell {
                    cell.configure(anyAssetTypes[0])
                    cell.selectionStyle = .none
                    cell.lblAny.accessibilityIdentifier = AccessibilityIds.CommonElements.cellAssetSelect(indexPath.row)
                    return cell
                }
            }
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
        AnalyticsManager.shared.selectAsset(account: AccountsRepository.shared.current)
        let cnt = viewModel?.assetSelectCellModelsFilter.count ?? 0

        if indexPath.row < cnt {
            let assetCellModel = viewModel?.assetSelectCellModelsFilter[indexPath.row] as? AssetSelectCellModel
            let asset = assetCellModel?.asset?.assetId
            self.didSelectAnyOrAsset(.asset(asset ?? ""))
        } else if indexPath.row == cnt {
            self.didSelectAnyOrAsset(AnyOrAsset.anyLiquid)
        } else if indexPath.row == cnt+1 {
            self.didSelectAnyOrAsset(AnyOrAsset.anyAmp)
        }
    }
}

extension AssetSelectViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
}
