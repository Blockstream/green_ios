import UIKit

class DialogAmpCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnCreate: UIButton!
    @IBOutlet weak var btnCopy: UIButton!
    var onCreate: (() -> Void)?
    var onCopy: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.titleCard)
        lblHint.setStyle(.txtCard)
        lblHint.numberOfLines = 0
        lblHint.lineBreakMode = .byCharWrapping
        bg.cornerRadius = 5.0
    }
    override func prepareForReuse() {
        lblTitle.text = ""
        lblHint.attributedText = nil
        lblHint.text = ""
        [btnCopy, btnCreate].forEach {
            $0?.isHidden = true
        }
    }
    func configure(model: DialogAmpCellModel,
                   onCreate: (() -> Void)? = nil,
                   onCopy: (() -> Void)? = nil) {
        self.onCreate = onCreate
        self.onCopy = onCopy
        lblTitle.text = model.name
        lblHint.attributedText = attributedHashText(model.hash)
        btnCreate.setStyle(.primary)
        btnCreate.setTitle("id_create".localized, for: .normal)
        btnCopy.isHidden = model.hash == nil
        btnCreate.isHidden = !(model.hash == nil)
    }

    private func attributedHashText(_ hash: String?) -> NSAttributedString? {
        guard let hash else { return nil }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byCharWrapping

        return NSAttributedString(
            string: "ID:\u{00A0}\(hash)",
            attributes: [
                .font: lblHint.font as Any,
                .foregroundColor: lblHint.textColor as Any,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    @IBAction func btnCreate(_ sender: Any) {
        btnCreate.setStyle(.primaryLoading)
        btnCreate.setTitle("Creating...".localized, for: .normal)
        onCreate?()
    }
    @IBAction func btnCopy(_ sender: Any) {
        onCopy?()
    }
}
