import UIKit

class DialogListCell: UITableViewCell {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var switchControl: UISwitch!
    var onSwitchChange: ((Int,Bool) -> Void)?
    var index: Int?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.txt)
        lblHint.setStyle(.txtSmaller)
        lblHint.textColor = .gW60()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: DialogCellModel,
                   index: Int? = nil,
                   onSwitchChange: ((Int,Bool) -> Void)? = nil) {
        guard let model = model as? DialogListCellModel else { return }
        self.index = index
        self.onSwitchChange = onSwitchChange
        icon.isHidden = true
        if let img = model.icon {
            icon.image = img
            icon.isHidden = false
        }
        lblTitle.text = model.title
        lblHint.text = model.hint
        lblHint.isHidden = model.hint == nil
        separator.isHidden = model.hint == nil
        if let switchState = model.switchState {
            switchControl.isOn = switchState
        } else {
            switchControl.isHidden = true
        }
    }

    @IBAction func switchDidChange(_ sender: Any) {
        guard let index = index else {return}
        onSwitchChange?(index,switchControl.isOn)
    }
}
