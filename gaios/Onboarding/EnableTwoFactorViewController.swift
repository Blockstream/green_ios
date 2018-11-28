import Foundation
import UIKit

class EnableTwoFactorViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableview: UITableView!
    struct FactorItem {
        var name: String
        var image: UIImage
        var enabled: Bool
    }
    var factors: [FactorItem] = []

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
        cell.textLabel?.text = self.factors[indexPath.row].name
        cell.imageView?.image = self.factors[indexPath.row].image
        cell.accessoryType = (self.factors[indexPath.row].enabled) ? .checkmark : .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section:
        Int) -> Int
    {
        return self.factors.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedFactor: FactorItem = self.factors[indexPath.row]
        if (selectedFactor.enabled) {
            return
        }
        switch selectedFactor.name {
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
        guard let config = AccountStore.shared.getTwoFactorConfig() else { return }
        if let email = config["email"] as? [String: Any] {
            factors.append(FactorItem(name: NSLocalizedString("id_email", comment: ""), image: UIImage.init(named: "email")!, enabled: email["enabled"] as! Int == 1 && email["confirmed"] as! Int == 1))
        }
        if let sms = config["sms"] as? [String: Any] {
            factors.append(FactorItem(name: NSLocalizedString("id_sms", comment: ""), image: UIImage.init(named: "sms")!, enabled: sms["enabled"] as! Int == 1 && sms["confirmed"] as! Int == 1))
        }
        if let phone = config["phone"] as? [String: Any] {
            factors.append(FactorItem(name: NSLocalizedString("id_call", comment: ""), image: UIImage.init(named: "phoneCall")!, enabled: phone["enabled"] as! Int == 1 && phone["confirmed"] as! Int == 1))
        }
        if let gauth = config["gauth"] as? [String: Any] {
            factors.append(FactorItem(name: NSLocalizedString("id_google_auth", comment: ""), image: UIImage.init(named: "gauth")!, enabled: gauth["enabled"] as! Int == 1 && gauth["confirmed"] as! Int == 1))
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
