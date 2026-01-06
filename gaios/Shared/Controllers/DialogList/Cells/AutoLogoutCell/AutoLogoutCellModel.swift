
class AutoLogoutCellModel: DialogCellModel {
    var type: DialogCellType

    let title: String
    let index: Int
    let selected: Bool
    let onSelected: ((Int) -> Void)?

    init(title: String, index: Int, selected: Bool, onSelected: ((Int) -> Void)?) {
        self.type = .autoLogout
        self.title = title
        self.index = index
        self.selected = selected
        self.onSelected = onSelected
    }
}
