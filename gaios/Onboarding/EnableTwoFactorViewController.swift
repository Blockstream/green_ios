import Foundation
import UIKit

class EnableTwoFactorViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableview: UITableView!
    var factors: [String] = []
    var images: [UIImage] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("id_twofactor_authentication", comment: "")
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =
            tableview.dequeueReusableCell(withIdentifier: "cell",
                                          for: indexPath as IndexPath)
        cell.textLabel?.text = self.factors[indexPath.row]
        cell.imageView?.image = self.images[indexPath.row]
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section:
        Int) -> Int
    {
        return self.factors.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch self.factors[indexPath.row] {
        case NSLocalizedString("id_email", comment: "") :
            self.performSegue(withIdentifier: "email", sender: nil)
            break
        case NSLocalizedString("id_sms", comment: "") :
            self.performSegue(withIdentifier: "phone", sender: "sms")
            break
        case NSLocalizedString("id_call", comment: "") :
            self.performSegue(withIdentifier: "phone", sender: "call")
            break
        case NSLocalizedString("id_google_auth", comment: "") :
            self.performSegue(withIdentifier: "gauth", sender: nil)
            break
        default:
            break
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        factors.removeAll()
        images.removeAll()
        if !AccountStore.shared.isEmailEnabled() {
            factors.append(NSLocalizedString("id_email", comment: ""))
            images.append(UIImage.init(named: "email")!)
        }
        if !AccountStore.shared.isSMSEnabled() {
            factors.append(NSLocalizedString("id_sms", comment: ""))
            images.append(UIImage.init(named: "sms")!)
        }
        if !AccountStore.shared.isPhoneEnabled() {
            factors.append(NSLocalizedString("id_call", comment: ""))
            images.append(UIImage.init(named: "phoneCall")!)
        }
        if !AccountStore.shared.isGauthEnabled() {
            factors.append(NSLocalizedString("id_google_auth", comment: ""))
            images.append(UIImage.init(named: "gauth")!)
        }
        tableview.reloadData()
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
}
