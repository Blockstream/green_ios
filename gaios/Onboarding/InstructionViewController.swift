import Foundation
import UIKit

class InstructionViewController: UIViewController {

    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var middleLabel: UILabel!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var topTitleLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    func setup() {
        topTitleLabel.attributedText = NSMutableAttributedString(string:  NSLocalizedString("id_save_your_mnemonic", comment: ""))
        topLabel.attributedText = NSMutableAttributedString(string:  NSLocalizedString("id_write_down_your_mnemonic_words", comment: ""))
        topLabel.setLineSpacing(lineSpacing: 3)
        middleLabel.attributedText = NSMutableAttributedString(string:  NSLocalizedString("id_dont_store_your_mnemonic_in", comment: ""))
        middleLabel.setLineSpacing(lineSpacing: 3)
        bottomLabel.attributedText = NSMutableAttributedString(string: NSLocalizedString("id_dont_take_screenshots_of_your", comment: ""))
        bottomLabel.setLineSpacing(lineSpacing: 3)
        nextButton.setDefaultButtonText(string: NSLocalizedString("id_next", comment: ""))
        nextButton.setGradient(true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        nextButton.updateGradientLayerFrame()
        bottomLabel.sizeToFit()
    }
}
