import Foundation
import UIKit

class InstructionViewController: UIViewController {

    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var bottomLabel: UILabel!


    override func viewDidLoad() {
        super.viewDidLoad()
        //customize
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
