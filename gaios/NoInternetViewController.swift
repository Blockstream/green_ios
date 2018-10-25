import Foundation
import  UIKit

class NoInternetViewController: UIViewController {

    @IBOutlet weak var bottomButton: UIButton!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var errorLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        errorLabel.text = NSLocalizedString("id_error", comment: "")
        descriptionLabel.text = NSLocalizedString("id_you_are_not_connected_to_the", comment: "")
        bottomButton.setTitle(NSLocalizedString("id_refresh", comment: ""), for: .normal)
    }

    @IBAction func refreshClicked(_ sender: Any) {
        print("recconect or do whatever needs to be done")
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bottomButton.layoutIfNeeded()
        bottomButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }
}
