import Foundation
import UIKit

enum DialogGroupType: CaseIterable {
    case walletPrefs
}

enum DialogGroupCellType: CaseIterable {
    case simple
}

protocol DialogGroupCellModel: AnyObject {
    var type: DialogGroupCellType { get }
}

class DialogGroupListViewModel {

    var title: String
    var dataSource: ([Int: String], [Int: [DialogGroupCellModel]]) = ([:], [:])
    var type: DialogGroupType

    init(title: String,
         type: DialogGroupType,
         dataSource: ([Int: String], [Int: [DialogGroupCellModel]]) = ([:], [:])
    ) {
        self.title = title
        self.dataSource = dataSource
        self.type = type
    }

    func rowsInSection(_ section: Int) -> Int {
        let data: [Int: [DialogGroupCellModel]] = dataSource.1
        guard let items = data[section] else { return 0 }
        return items.count
    }
    func modeTypeAt(_ indexPath: IndexPath) -> DialogGroupCellType {
        let data: [Int: [DialogGroupCellModel]] = dataSource.1
        guard let items = data[indexPath.section] else { return .simple }
        return items[indexPath.row].type
    }
    func modelAt(_ indexPath: IndexPath) -> DialogGroupCellModel? {
        let data: [Int: [DialogGroupCellModel]] = dataSource.1
        guard let items = data[indexPath.section] else { return nil }
        return items[indexPath.row]
    }
    func sectionName(_ section: Int) -> String {
        let sections: [Int: String] = dataSource.0
        return sections[section] ?? ""
    }
}
