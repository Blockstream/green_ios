import Foundation
import UIKit

class InstructionViewController: UIViewController {

    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var middleLabel: UILabel!
    @IBOutlet weak var topLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("id_save_your_recovery_seed", comment: "")
        topLabel.text = NSLocalizedString("id_write_down_your_seed_words_on", comment: "")
        middleLabel.text = NSLocalizedString("id_dont_store_your_seed_in_email", comment: "")
        bottomLabel.text = NSLocalizedString("id_dont_take_screenshots_of_your", comment: "")
        nextButton.setTitle(NSLocalizedString("id_next", comment: ""), for: .normal)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        nextButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
        bottomLabel.sizeToFit()
    }
}
