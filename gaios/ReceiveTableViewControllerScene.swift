//
//  ReceiveTableViewControllerScene.swift
//  gaios
//

import UIKit

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
}

class ReceiveTableViewURIItem: ReceiveTableViewItem {
    var type: ReceiveTableViewItemType {
        return .uri
    }

    var identifier: String {
        return "URITableCell"
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

extension ReceiveTableViewItemSection {
    var items: [ReceiveTableViewItem] {
        return [ReceiveTableViewItem]()
    }
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

    var items: [ReceiveTableViewItem] {
        return [ReceiveTableViewURIItem(),
                ReceiveTableViewAddressItem(address: "XXX")]
    }
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

    var items: [ReceiveTableViewItem] {
        return [ReceiveTableViewAmountItem(),
                ReceiveTableViewPermanentPaymentURLItem(),
                ReceiveTableViewSweepItem()]
    }
}

class ReceiveTableViewModel: NSObject {
    var sections = [ReceiveTableViewItemSection]()

    override init() {
        super.init()

        sections.append(ReceiveTableViewAddressSection())
        sections.append(ReceiveTableViewAdvancedSection())
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
            let cell = tableView.dequeueReusableCell(withIdentifier: item.items[indexPath.row].identifier, for: indexPath);
            return cell
        case .advanced:
            let cell = tableView.dequeueReusableCell(withIdentifier: item.items[indexPath.row].identifier, for: indexPath)
            return cell
        }
    }
}

class ReceiveTableViewControllerScene: UITableViewController {
    fileprivate let viewModel = ReceiveTableViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = viewModel

        tableView.tableFooterView = UIView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
