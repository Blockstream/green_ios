import UIKit

class EditCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var textField: UITextField!
    var onChange: ((Int?) -> Void)?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        textField.addDoneButtonToKeyboard(myAction: #selector(self.textField.resignFirstResponder))
        textField.placeholder = "id_number_of_consecutive_empty".localized
        textField.textColor = .white
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(number: Int?, onChange: ((Int?) -> Void)?) {
        self.textField.text = if let number { "\(number)" } else { "" }
        self.onChange = onChange
    }
    @IBAction func textFieldChange(_ sender: Any) {
        let number = Int(textField.text ?? "")
        onChange?(number)
    }
}
