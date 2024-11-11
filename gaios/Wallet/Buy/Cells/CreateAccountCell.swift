import UIKit

class CreateAccountCell: UITableViewCell {

    @IBOutlet weak var bgView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    var onTap: (() -> Void)?
    
    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        bgView.cornerRadius = 5.0
        nextButton.isUserInteractionEnabled = false
        nextButton.backgroundColor = UIColor.gGreenMatrix()
        nextButton.cornerRadius = 4.0
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(onTap: (() -> Void)?) {
        titleLabel.text = "id_create_new_account".localized
        self.onTap = onTap
    }
    
    @IBAction func didTap(_ sender: Any) {
        self.onTap?()
    }
}
