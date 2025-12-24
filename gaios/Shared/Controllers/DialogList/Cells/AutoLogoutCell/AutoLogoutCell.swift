import UIKit

class AutoLogoutCell: UITableViewCell {
    private var isCurrentOption = false
    private var onSelect: ((Int) -> Void)?
    private var index: Int?

    class var identifier: String { return String(describing: self) }

    @IBOutlet weak var optionButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()

        optionButton.addTarget(self, action: #selector(onSelectOption), for: .touchUpInside)

    }

    func configure(
        _ model: DialogCellModel
    ) {
        guard let model = model as? AutoLogoutCellModel else { return }

        index = model.index
        onSelect = model.onSelected
        optionButton.setTitle(model.title, for: .normal)
        isCurrentOption = model.selected

        handleSelectionStatus()
    }

    @objc private func onSelectOption() {
        isCurrentOption = true
        handleSelectionStatus()
        onSelect?(index ?? 0)
    }

    private func handleSelectionStatus() {
        if (isCurrentOption) {
            optionButton.backgroundColor = UIColor.gBlackBg()
        } else {
            optionButton.backgroundColor = UIColor.gGrayBtn()
        }
    }
}
