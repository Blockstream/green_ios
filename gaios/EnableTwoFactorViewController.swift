import Foundation
import UIKit

class EnableTwoFactorViewController : UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
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
