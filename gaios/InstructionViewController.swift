import Foundation
import UIKit

class InstructionViewController: UIViewController {

    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var middleLabel: UILabel!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = NSLocalizedString("psave_your_recovery_seed", comment: "")
        topLabel.text = NSLocalizedString("pwrite_down_your_seed_words_on", comment: "")
        middleLabel.text = NSLocalizedString("pdont_store_your_seed_in_email", comment: "")
        bottomLabel.text = NSLocalizedString("pdont_take_screenshots_of_your", comment: "")
        nextButton.setTitle(NSLocalizedString("pnext", comment: ""), for: .normal)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        nextButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
        bottomLabel.sizeToFit()
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

}
