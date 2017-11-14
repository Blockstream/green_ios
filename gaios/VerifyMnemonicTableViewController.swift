//
//  VerifyMnemonicTableViewController.swift
//  gaios
//

import UIKit

class MnemonicSuggestionUIInputView: UIInputView {
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 24), inputViewStyle: .keyboard)
    }

    override init(frame: CGRect, inputViewStyle: UIInputViewStyle) {
        super.init(frame: frame, inputViewStyle: inputViewStyle)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

class MnemonicTableViewCellUITextField: UITextField {
    var associatedRow: Int? = nil
}

class MnemonicTableViewCell: UITableViewCell {
    @IBOutlet weak var wordLabel: UILabel!
    @IBOutlet weak var wordEntered: MnemonicTableViewCellUITextField!
}

class VerifyMnemonicTableViewController: UITableViewController, UITextFieldDelegate {

    var wordNumbers: [UInt8] = [UInt8](repeating: 0, count: 5)

    func generateWordNumber(_ bottom: UInt8, _ top: UInt8) -> UInt8 {
        let range: UInt8 = (top - bottom) + 1
        let discard: UInt8 = 255 - 255 % range
        var randomWord: UInt8 = discard
        while randomWord >= discard {
            withUnsafeMutablePointer(to: &randomWord) { (pointer) -> Void in
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, pointer)
            }
        }
        randomWord = randomWord % range
        return randomWord + bottom
    }

    func generateRandomWordNumbers() {
        repeat {
            wordNumbers = wordNumbers.map { (_) -> UInt8 in generateWordNumber(0, 23) }
        } while Set(wordNumbers).count != 5
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        generateRandomWordNumbers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Please confirm the following words from your mnemonic passphrase"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MnemonicTableCell", for: indexPath) as! MnemonicTableViewCell

        cell.wordEntered!.delegate = self
        cell.wordEntered!.associatedRow = indexPath.row
        cell.wordEntered!.inputAccessoryView = MnemonicSuggestionUIInputView()
        cell.wordLabel!.text = "\(wordNumbers[indexPath.row] + 1)."

        return cell
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        let currentRow = textField as! MnemonicTableViewCellUITextField
        guard let mnemonicWords = getAppDelegate().getMnemonicWords() else {
            return false
        }
        print("currentRow " + currentRow.text! + " " + mnemonicWords[currentRow.associatedRow!])
        return currentRow.text == nil || currentRow.text! == mnemonicWords[currentRow.associatedRow!]
    }
}
