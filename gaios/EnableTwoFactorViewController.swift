import Foundation
import UIKit

class EnableTwoFactorViewController : UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var emailButton: UIButton!
    @IBOutlet weak var smsButton: UIButton!
    @IBOutlet weak var phoneCallButton: UIButton!
    @IBOutlet weak var gauthButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = NSLocalizedString("ptwo_factor_authentication", comment: "")
        emailButton.setTitle(NSLocalizedString("pemail", comment: ""), for: .normal)
        smsButton.setTitle(NSLocalizedString("psms", comment: ""), for: .normal)
        phoneCallButton.setTitle(NSLocalizedString("pcall", comment: ""), for: .normal)
        gauthButton.setTitle(NSLocalizedString("pgoogle_auth", comment: ""), for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }

    @IBAction func phoneCallClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "phone", sender: "call")
    }

    @IBAction func smsClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "phone", sender: "sms")
    }

    @IBAction func gauthClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "gauth", sender: nil)
    }

    @IBAction func emailClicked(_ sender: Any) {
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SetPhoneViewController {
            if (sender as! String == "sms") {
                nextController.sms = true
            } else {
                nextController.phoneCall = true
            }
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

}
