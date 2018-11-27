import Foundation
import UIKit

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    let settingsIcon:[UIImage] = [#imageLiteral(resourceName: "account"),#imageLiteral(resourceName: "security"),#imageLiteral(resourceName: "advanced"),#imageLiteral(resourceName: "about")]
    @IBOutlet weak var fotterView: UIView!

    var sections: Array<SettingsSection> = Array<SettingsSection>()
    var anyEnabled: Bool = false
    var isResetData = AccountStore.shared.getTwoFactorResetData()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = fotterView
        tableView.separatorColor = UIColor.customTitaniumLight()
        sections = SettingsStore.shared.getAllSections()
    }

    @IBAction func logoutClicked(_ sender: Any) {
        wrap {
            try getSession().disconnect()
        }.done {
            AccountStore.shared.isWatchOnly = false
            getAppDelegate().lock()
        }.catch { error in
            print("problem while logging out")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SettingsStore.shared.refreshTwoFactorSettings()
        sections = SettingsStore.shared.getAllSections()
        tableView.reloadData()
        // Load 2fa from gdk
        DispatchQueue.global(qos: .userInteractive).async {
            wrap() {
                try! getSession().getTwoFactorConfig()!
            }.done { (result: [String: Any]) in
                self.anyEnabled = result["any_enabled"] as! Bool
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }.catch {_ in
                print("error")
            }
        }
        isResetData = AccountStore.shared.getTwoFactorResetData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let settingsGroup = sections[section]
        return  settingsGroup.settingsInSection.count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return  sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath) as! SettingsCell
        let section = sections[indexPath.section]
        let settings = section.settingsInSection[indexPath.row]

        cell.label.text = settings.text
        cell.rightLabel.text = settings.secondaryText
        cell.selectionStyle = .none
        cell.separatorInset = UIEdgeInsetsMake(0, 16, 0, 10)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 45
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(AccountStore.shared.isWatchOnly) {
              if (indexPath.section == 0) {
                if (indexPath.row == 1) {
                    if let url = URL(string: SettingsStore.shared.tosURL) {
                        UIApplication.shared.open(url, options: [:])
                    }
                } else if (indexPath.row == 2) {
                    if let url = URL(string: SettingsStore.shared.privacyPolicyURL) {
                        UIApplication.shared.open(url, options: [:])
                    }
                }
            }
        } else {
            if(indexPath.section == 0) {
                if (indexPath.row == 0) {
                    self.performSegue(withIdentifier: "currency", sender: nil)
                } else if (indexPath.row == 1) {
                    self.performSegue(withIdentifier: "denomination", sender: nil)
                } else if (indexPath.row == 2) {
                    self.performSegue(withIdentifier: "transactionFee", sender: nil)
                } else if (indexPath.row == 3) {
                    self.performSegue(withIdentifier: "watchOnly", sender: nil)
                }
            } else if (indexPath.section == 1) {
                if (indexPath.row == 0) {
                    self.performSegue(withIdentifier: "recovery", sender: nil)
                } else if (indexPath.row == 1) {
                    self.performSegue(withIdentifier: "screenLock", sender: nil)
                } else if (indexPath.row == 2) {
                    if !isResetData.isReset && !isResetData.isDisputed {
                        self.performSegue(withIdentifier: "editTwoFactor", sender: nil)
                    }
                } else if (indexPath.row == 3) {
                    if anyEnabled  && !isResetData.isReset && !isResetData.isDisputed {
                        self.performSegue(withIdentifier: "twoFactorLimit", sender: nil)
                    }
                } else if (indexPath.row == 4) {
                    if anyEnabled {
                        self.performSegue(withIdentifier: "twoFactorReset", sender: nil)
                    }
                } else if (indexPath.row == 5) {
                    self.performSegue(withIdentifier: "autolock", sender: nil)
                } else if (indexPath.row == 6) {
                    if let url = URL(string: SettingsStore.shared.supportURL) {
                        UIApplication.shared.open(url, options: [:])
                    }
                }
            } else if (indexPath.section == 2) {
                if (indexPath.row == 0) {
                    self.performSegue(withIdentifier: "switch", sender: sections[indexPath.section].settingsInSection[indexPath.row])
                } else if (indexPath.row == 1) {
                    self.performSegue(withIdentifier: "requestNlock", sender: nil)
                }
            } else if (indexPath.section == 3) {
                if (indexPath.row == 1) {
                    if let url = URL(string: SettingsStore.shared.tosURL) {
                        UIApplication.shared.open(url, options: [:])
                    }
                } else if (indexPath.row == 2) {
                    if let url = URL(string: SettingsStore.shared.privacyPolicyURL) {
                        UIApplication.shared.open(url, options: [:])
                    }
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? ToggleSettingsViewController {
            nextController.settings = sender as? SettingsItem
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionItem = sections[section]
        let header = UIView()
        header.backgroundColor = UIColor.customTitaniumDark()
        let imageView = UIImageView()
        imageView.frame = CGRect(x: 0, y: 0, width: 21, height: 21)
        imageView.image = settingsIcon[section]
        header.insertSubview(imageView, at: 0)
        let title = UILabel()
        title.text = sectionItem.sectionName
        title.frame = CGRect(x: 0, y: 0, width: 21, height: 41)
        title.translatesAutoresizingMaskIntoConstraints = false
        title.textColor = UIColor.customTitaniumLight()
        header.insertSubview(title, at: 1)
        //constrain <-16[image]->16 [Title]
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 21).isActive = true
        NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 21).isActive = true
        NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 16).isActive = true
        NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0).isActive = true

        NSLayoutConstraint(item: title, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: title, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: imageView, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: 5).isActive = true

        return header
    }
}
