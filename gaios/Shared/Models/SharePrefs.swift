import UIKit

enum SharePrefs: Int, CaseIterable {
    case address = 0
    case qr = 1
    case invoice = 2

    var name: String {
        switch self {
        case .address:
            return "id_address".localized
        case .qr:
            return "id_qr_code".localized
        case .invoice:
            return "id_invoice".localized
        }
    }

    var icon: UIImage {
        switch self {
        case .address:
            return UIImage(named: "ic_dialog_text_Aa")!.maskWithColor(color: .white)
        case .qr:
            return UIImage(named: "ic_dialog_qr")!.maskWithColor(color: .white)
        case .invoice:
            return UIImage(named: "ic_dialog_text_Aa")!.maskWithColor(color: .white)
        }
    }

    static func getItems(_ isInvoice: Bool? = false) -> [DialogListCellModel] {
        var items: [DialogListCellModel] = []
        if isInvoice == true {
            let pref = SharePrefs.invoice
            items.append(DialogListCellModel(type: .list,
                                             icon: pref.icon,
                                             title: pref.name))
        } else {
            let pref = SharePrefs.address
            items.append(DialogListCellModel(type: .list,
                                             icon: pref.icon,
                                             title: pref.name))
        }
        let pref = SharePrefs.qr
        items.append(DialogListCellModel(type: .list,
                                            icon: pref.icon,
                                            title: pref.name))
        return items
    }
}
