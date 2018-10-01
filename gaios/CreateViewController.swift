//
//  CreateViewController.swift
//  GreenBitsIOS
//

import UIKit

class CreateViewController: UITableViewController {

    var mnemonicWordsSelected: [Bool] = [Bool](repeating: false, count: 24)

    override func viewDidLoad() {
        super.viewDidLoad()

        if getAppDelegate().getMnemonicWords() == nil {
            getAppDelegate().setMnemonicWords(try! generateMnemonic().components(separatedBy: " "))
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 24
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Please save and secure your 24 words mnemonic passphrase"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MnemonicTableCell", for: indexPath)

        cell.textLabel?.text = "\(indexPath.row + 1).\t" + getAppDelegate().getMnemonicWords()![indexPath.row]
        cell.accessoryType = mnemonicWordsSelected[indexPath.row] ? .checkmark : .none

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        mnemonicWordsSelected[indexPath.row] = mnemonicWordsSelected[indexPath.row] ? false : true

        tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.fade)
    }
}
