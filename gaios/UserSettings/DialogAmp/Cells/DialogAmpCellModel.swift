import Foundation

class DialogAmpCellModel {
    let name: String
    let hash: String?
    init(name: String, hash: String? = nil) {
        self.name = name
        self.hash = hash
    }
}
