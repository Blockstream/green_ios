import UIKit

class ShowMnemonicHeaderView: UIView {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        setContent()
        setStyle()
    }

    func setContent() {
        titleLabel.text = "id_recovery_phrase".localized
        descriptionLabel.text = "id_the_recovery_phrase_can_be_used".localized
    }

    func setStyle() {
        titleLabel.setStyle(.subTitle)
        titleLabel.textColor = .black
        descriptionLabel.setStyle(.txtCard)
    }
}
