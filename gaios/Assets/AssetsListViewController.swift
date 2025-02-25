import Foundation
import UIKit
import core
import gdk

protocol AssetsListViewControllerDelegate: AnyObject {
    func didSelect(assetId: String, index: Int?)
}

class AssetsListViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnDismiss: UIButton!

    var assetAmountList: AssetAmountList!
    var index: Int?

    weak var delegate: AssetsListViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "id_select_asset".localized

        view.accessibilityIdentifier = AccessibilityIdentifiers.AssetsListScreen.view
        tableView.accessibilityIdentifier = AccessibilityIdentifiers.AssetsListScreen.table
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(onAssetsUpdated), name: NSNotification.Name(rawValue: EventType.AssetsUpdated.rawValue), object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.AssetsUpdated.rawValue), object: nil)
    }

    @IBAction func btnDismiss(_ sender: Any) {
        dismiss(animated: true)
    }

    @objc func onAssetsUpdated(_ notification: NSNotification) {
        self.tableView.reloadData()
    }
}

extension AssetsListViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return assetAmountList.amounts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "AssetCell") as? AssetCell {
            let assetAmount = assetAmountList.amounts[indexPath.row]
            let tag = assetAmount.0
            let info = assetAmountList.assets[tag]
            let icon = WalletManager.current?.image(for: tag)
            let satoshi = assetAmount.1
            cell.configure(tag: tag, info: info, icon: icon, satoshi: satoshi)
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let tag = assetAmountList.amounts[indexPath.row].0
        delegate?.didSelect(assetId: tag, index: index)
        dismiss(animated: true)
    }
}
