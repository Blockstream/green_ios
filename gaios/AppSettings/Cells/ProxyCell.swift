import UIKit
import core

class ProxyCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var bgField: UIView!
    @IBOutlet weak var textfield: UITextField!
    var onChange: ((String) -> Void)?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 6.0
        lblTitle.text = "id_server_ip_and_port_ipport".localized
        textfield.placeholder = "id_server_ip_and_port_ipport".localized
        [lblTitle].forEach {
            $0?.setStyle(.txtCard)
        }
        [textfield].forEach {
            $0.textColor = .white
            $0.addDoneButtonToKeyboard(myAction: #selector($0.resignFirstResponder))
        }
        [bgField].forEach {
            $0.setStyle(CardStyle.defaultStyle)
        }
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(value: String,
                   onChange: ((String) -> Void)?
    ) {
        self.textfield.text = value
        self.onChange = onChange
    }
    @IBAction func textFieldChange(_ sender: Any) {
        onChange?(self.textfield.text ?? "")
    }
}
