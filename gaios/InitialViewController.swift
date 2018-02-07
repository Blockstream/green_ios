//
//  InitialViewController.swift
//  GreenBitsIOS
//
//

import UIKit

class InitialViewController: UIViewController {
    @IBOutlet weak var userProvidedMnemonic: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        wrap {
            try getSession().connect(network: Network.TestNet, debug: true)
        }.then {
            print("Connected to TestNet")
        }.catch { error in
            print("Connection failed")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func goAction(_ sender: Any) {
        print("User Provided Mnemonic " + userProvidedMnemonic.text!)
        let trimmedUserProvidedMnemonic = "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive spike pond industry time hero trim verb mammal asthma".trimmingCharacters(in: .whitespacesAndNewlines)
        retry(session: getSession(), network: Network.TestNet) {
            wrap { return try getSession().login(mnemonic: trimmedUserProvidedMnemonic) }
        }.then { (loginData: [String: Any]?) -> Void in
            getGAService().loginData = loginData
            self.performSegue(withIdentifier: "MainViewSegue", sender: self)
        }.catch { error in
            print("Login failed")
        }
    }

    @IBAction func showMnemonicAction(_ sender: Any) {
        let showMnemonic = sender as! UISwitch
        userProvidedMnemonic.isSecureTextEntry = showMnemonic.isOn ? false : true
    }

    @IBAction func unwindToInitialViewController(segue: UIStoryboardSegue) {
    }
}
