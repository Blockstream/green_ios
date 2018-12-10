import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class EnableTwoFactorViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, NVActivityIndicatorViewable {

    @IBOutlet weak var tableview: UITableView!
    @IBOutlet weak var walletButton: UIButton!
    var errorLabel: UIErrorLabel!

    struct FactorItem {
        var name: String
        var image: UIImage
        var enabled: Bool
        var type: TwoFactorType
    }
    var factors = [FactorItem]()
    var isHiddenWalletButton: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("id_twofactor_authentication", comment: "")
        errorLabel = UIErrorLabel(self.view)
        walletButton.isHidden = isHiddenWalletButton
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
            disable(selectedFactor.type)
            return
        }
        switch selectedFactor.type {
        case .email:
            self.performSegue(withIdentifier: "email", sender: nil)
            break
        case .sms:
            self.performSegue(withIdentifier: "phone", sender: "sms")
            break
        case .phone:
            self.performSegue(withIdentifier: "phone", sender: "call")
            break
        case .gauth:
            self.performSegue(withIdentifier: "gauth", sender: nil)
            break
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    func reloadData() {
        guard let dataTwoFactorConfig = try? getSession().getTwoFactorConfig() else { return }
        guard let twoFactorConfig = try? JSONDecoder().decode(TwoFactorConfig.self, from: JSONSerialization.data(withJSONObject: dataTwoFactorConfig!, options: [])) else { return }
        factors.removeAll()
        factors.append(FactorItem(name: NSLocalizedString("id_email", comment: ""), image: UIImage.init(named: "email")!, enabled: twoFactorConfig.email.enabled && twoFactorConfig.email.confirmed, type: .email))
        factors.append(FactorItem(name: NSLocalizedString("id_sms", comment: ""), image: UIImage.init(named: "sms")!, enabled: twoFactorConfig.sms.enabled && twoFactorConfig.sms.confirmed, type: .sms))
        factors.append(FactorItem(name: NSLocalizedString("id_call", comment: ""), image: UIImage.init(named: "phoneCall")!, enabled: twoFactorConfig.phone.enabled && twoFactorConfig.phone.confirmed, type: .phone))
        factors.append(FactorItem(name: NSLocalizedString("id_google_auth", comment: ""), image: UIImage.init(named: "gauth")!, enabled: twoFactorConfig.gauth.enabled && twoFactorConfig.gauth.confirmed, type: .gauth))
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

    func disable(_ type: TwoFactorType) {
        let bgq = DispatchQueue.global(qos: .background)
        let config = TwoFactorConfigItem(enabled: false, confirmed: false, data: "")
        firstly {
            self.errorLabel.isHidden = true
            self.startAnimating()
            return Guarantee()
        }.compactMap(on: bgq) {
            try getGAService().getSession().changeSettingsTwoFactor(method: type.rawValue, details: try JSONSerialization.jsonObject(with: JSONEncoder().encode(config), options: .allowFragments) as! [String : Any])
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.ensure {
            self.stopAnimating()
        }.done { _ in
            self.reloadData()
        }.catch { error in
            self.errorLabel.isHidden = false
            if let twofaError = error as? TwoFactorCallError {
                switch twofaError {
                case .failure(let localizedDescription):
                    self.errorLabel.text = localizedDescription
                }
            } else {
                self.errorLabel.text = error.localizedDescription
            }
        }
    }
}
