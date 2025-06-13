import Foundation
import UIKit

class SelectProviderViewModel {

    var title = "id_change_exchange".localized
    var quotes = [MeldQuoteItem]()

    init(quotes: [MeldQuoteItem]) {
        self.quotes = quotes
    }

//    func rowsInSection(_ section: Int) -> Int {
//        let data: [Int: [DialogGroupCellModel]] = dataSource.1
//        guard let items = data[section] else { return 0 }
//        return items.count
//    }
//    func modeTypeAt(_ indexPath: IndexPath) -> DialogGroupCellType {
//        let data: [Int: [DialogGroupCellModel]] = dataSource.1
//        guard let items = data[indexPath.section] else { return .simple }
//        return items[indexPath.row].type
//    }
//    func modelAt(_ indexPath: IndexPath) -> DialogGroupCellModel? {
//        let data: [Int: [DialogGroupCellModel]] = dataSource.1
//        guard let items = data[indexPath.section] else { return nil }
//        return items[indexPath.row]
//    }
//    func sectionName(_ section: Int) -> String {
//        let sections: [Int: String] = dataSource.0
//        return sections[section] ?? ""
//    }
}
