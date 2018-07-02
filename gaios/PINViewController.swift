//
//  PINViewController.swift
//  gaios
//

import UIKit

class PinViewController: UIViewController {

    @IBOutlet weak var pinTextField: UITextField!

    @IBAction func pinTextFieldTouched(_ sender: UITextField) {
        print("textfield touched")
    }

    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        print("done pressed" + pinTextField.text!)
        let pin = pinTextField.text
        let mnemonics = getAppDelegate().getMnemonicWordsString()
        wrap { return try getSession().setPin(mnemonic: mnemonics!, pin: pin!, device: "bla") }
            .done { (pinData: String) in
                let login = pinData
                print("pin data: " + login)
                print("setPin succeded")
                KeychainHelper.savePassword(service: "pinData", account: "user", data: pinData)
                self.performSegue(withIdentifier: "showMainMenu", sender: self)
            }.catch { error in
                print("setPin failed")
        }
    }

    func loginWithPinData(_ pin: String, pinData: String) {
        retry(session: getSession(), network: getNetwork()) {
            wrap { return try getSession().login(pin: pin, pin_identifier_and_secret: pinData) }
            }.done { (loginData: [String: Any]?) in
                getGAService().loginData = loginData
                print("Login successful")
            }.catch { error in
                print("login failed")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        pinTextField.keyboardType = UIKeyboardType.numberPad
        pinTextField.becomeFirstResponder()
    }
}
