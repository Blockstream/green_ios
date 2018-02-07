//
//  ReceiveTableViewControllerScene.swift
//  gaios
//

import UIKit
import PromiseKit

enum ReceiveTableViewItemType {
    case uri
    case address
    case amount
    case permanent_payment_url
    case sweep
}

protocol ReceiveTableViewItem {
    var type: ReceiveTableViewItemType { get }
    var identifier: String { get }
    var text: String? { get }
    var detailText: String? { get }
}

extension ReceiveTableViewItem {
    var text: String? { return nil }
    var detailText: String? { return nil }
}

class ReceiveTableViewURIItem: ReceiveTableViewItem {
    var type: ReceiveTableViewItemType {
        return .uri
    }

    var identifier: String {
        return "URITableCell"
    }

    var address: String?

    init(address: String?) {
        self.address = address
    }
}

class ReceiveTableViewAddressItem: ReceiveTableViewItem {
    var type: ReceiveTableViewItemType {
        return .address
    }

    var identifier: String {
        return "AddressTableCell"
    }

    var address: String?

    init(address: String?) {
        self.address = address
    }
}

class ReceiveTableViewAmountItem: ReceiveTableViewItem {
    var type: ReceiveTableViewItemType {
        return .amount
    }

    var identifier: String {
        return "AmountTableCell"
    }
}

class ReceiveTableViewPermanentPaymentURLItem: ReceiveTableViewItem {
    var type: ReceiveTableViewItemType {
        return .permanent_payment_url
    }

    var identifier: String {
        return "PermanentPaymentURLTableCell"
    }
}

class ReceiveTableViewSweepItem: ReceiveTableViewItem {
    var type: ReceiveTableViewItemType {
        return .sweep
    }

    var identifier: String {
        return "PrivateKeyTableCell"
    }
}

enum ReceiveTableViewItemSectionType {
    case address
    case advanced
}

protocol ReceiveTableViewItemSection {
    var type: ReceiveTableViewItemSectionType { get }
    var rowCount: Int { get }
    var sectionTitle: String { get }
    var items: [ReceiveTableViewItem] { get }
}

class ReceiveTableViewAddressSection: ReceiveTableViewItemSection {
    var type: ReceiveTableViewItemSectionType {
        return .address
    }

    var sectionTitle: String {
        return "Address"
    }

    var rowCount: Int {
        return 2
    }

    var items = [ReceiveTableViewItem]()
}

class ReceiveTableViewAdvancedSection: ReceiveTableViewItemSection {
    var type: ReceiveTableViewItemSectionType {
        return .advanced
    }

    var sectionTitle: String {
        return "Advanced"
    }

    var rowCount: Int {
        return 3
    }

    var items = [ReceiveTableViewItem]()
}

class URICell: UITableViewCell {

    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var detail: UILabel!


    var item: ReceiveTableViewItem? {
        didSet {
            guard let item = item as? ReceiveTableViewURIItem else {
                return
            }

            self.title.text = "URI:"
            self.detail.text = item.address
        }
    }
}

class AddressCell: UITableViewCell {

    @IBOutlet weak var title: UILabel!

    var item: ReceiveTableViewItem? {
        didSet {
            guard let item = item as? ReceiveTableViewAddressItem else {
                return
            }

            self.title.text = item.address ?? String()
        }
    }
}

class AmountCell: UITableViewCell {
    var item: ReceiveTableViewItem? {
        didSet {

        }
    }
}

class PermanentPaymentURLCell: UITableViewCell {
    var item: ReceiveTableViewItem? {
        didSet {

        }
    }
}

class PrivateKeyCell: UITableViewCell {
    var item: ReceiveTableViewItem? {
        didSet {

        }
    }
}

class ReceiveTableViewModel: NSObject {
    var sections = [ReceiveTableViewItemSection]()

    func generateAddress() -> Promise<String> {
        return retry(session: getSession(), network: Network.TestNet) {
            return wrap { return try getSession().getReceiveAddress() }
        }
    }

    override init() {
        super.init()

        let addressSection = ReceiveTableViewAddressSection()
        addressSection.items.append(ReceiveTableViewURIItem(address: String()))
        addressSection.items.append(ReceiveTableViewAddressItem(address: String()))
        sections.append(addressSection)

        let advancedSection = ReceiveTableViewAdvancedSection()
        advancedSection.items.append(ReceiveTableViewAmountItem())
        advancedSection.items.append(ReceiveTableViewPermanentPaymentURLItem())
        advancedSection.items.append(ReceiveTableViewSweepItem())
        sections.append(advancedSection)
    }

    func updateViewModel(tableView: UITableView) {
        generateAddress().then { (address: String) -> Void in
            guard let item = self.sections[0].items[1] as? ReceiveTableViewAddressItem else {
                return
            }
            item.address = address

            guard let uriItem = self.sections[0].items[0] as? ReceiveTableViewURIItem else {
                return
            }
            uriItem.address = address

            tableView.reloadData()
        }
    }
}

extension ReceiveTableViewModel: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].sectionTitle
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rowCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section]
        switch item.type {
        case .address:
            let rowItem = item.items[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: rowItem.identifier, for: indexPath);
            switch rowItem.type {
            case .address:
                let addressCell = cell as! AddressCell
                addressCell.item = rowItem
                return cell
            case .uri:
                let uriCell = cell as! URICell
                uriCell.item = rowItem
                return cell
            default:
                return cell
            }
        case .advanced:
            let cell = tableView.dequeueReusableCell(withIdentifier: item.items[indexPath.row].identifier, for: indexPath)
            return cell
        }
    }
}

class ReceiveTableViewControllerScene: UITableViewController {
    fileprivate let viewModel = ReceiveTableViewModel()

    var address: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = viewModel

        tableView.tableFooterView = UIView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        viewModel.updateViewModel(tableView: self.tableView)
    }

    func generateQRCode(_ text: String, _ frame: CGRect) -> UIImage {
        let data = text.data(using: String.Encoding.ascii, allowLossyConversion: false)

        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter!.setValue(data, forKey: "inputMessage")
        filter!.setValue("Q", forKey: "inputCorrectionLevel")

        let image = filter!.outputImage!
        let scaleX = frame.size.width / image.extent.size.width
        let scaleY = frame.size.height / image.extent.size.height
        let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        return UIImage(ciImage: scaledImage)
    }
}
