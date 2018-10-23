import Foundation
import UIKit

class RequestNLockEmails : UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var requestButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = NSLocalizedString("prequest_nlocktime", comment: "")
        descriptionLabel.text = NSLocalizedString("prequest_will_send", comment: "")
        requestButton.setTitle(NSLocalizedString("prequest", comment: ""), for: .normal)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func requestClicked(_ sender: Any) {
        //make a request
    }
}
