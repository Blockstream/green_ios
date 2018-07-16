//
//  EnterMnemonicTableViewController.swift
//  gaios
//


import UIKit

class EnterMnemonicTableViewCell: UITableViewCell {
    @IBOutlet weak var wordLabel: UILabel!
    @IBOutlet weak var wordEntered: MnemonicTableViewCellUITextField!
}

class EnterMnemonicTableViewController: UITableViewController, UITextFieldDelegate {

    private var mnemonicWords = [String]()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        //self.navigationController?.setNavigationBarHidden(true, animated: animated)

        mnemonicWords = Array(repeating: String(), count: 27)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        mnemonicWords = Array(repeating: String(), count: 27)

        //self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 27
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Please enter your mnemonic passphrase"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MnemonicTableCell", for: indexPath) as! EnterMnemonicTableViewCell

        cell.wordEntered!.delegate = self
        cell.wordEntered!.associatedRow = indexPath.row
        cell.wordEntered!.inputAccessoryView = MnemonicSuggestionUIInputView()
        cell.wordLabel!.text = "\(indexPath.row + 1)."

        return cell
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        let currentRow = textField as! MnemonicTableViewCellUITextField
        print("currentRow " + currentRow.text!)
        mnemonicWords[currentRow.associatedRow!] = currentRow.text!
        return true
    }

    @IBAction func doneEnterMnemonic(_ sender: Any) {
        // FIXME: erase it securely
        let _ = mnemonicWords.joined(separator: " ")
        let trimmedUserProvidedMnemonic = getNetwork() == Network.LocalTest ? "cotton slot artwork now grace assume syrup route moment crisp cargo sock wrap duty craft joy adult typical nut mad way autumn comic silent".trimmingCharacters(in: .whitespacesAndNewlines) : "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive spike pond industry time hero trim verb mammal asthma".trimmingCharacters(in: .whitespacesAndNewlines)
        retry(session: getSession(), network: getNetwork()) {
            wrap { return try getSession().login(mnemonic: trimmedUserProvidedMnemonic) }
        }.done { (loginData: [String: Any]?) in
            getGAService().loginData = loginData
            AccountStore.shared.initializeAccountStore()
            self.performSegue(withIdentifier: "MainEnterMnemonicSegue", sender: self)
        }.catch { error in
            print("Login failed")
        }
    }
}
