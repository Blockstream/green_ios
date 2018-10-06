//
//  EditTwoFactorViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 10/4/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class EditTwoFactorViewController: UIViewController {

    @IBOutlet weak var emailSwitch: UISwitch!
    @IBOutlet weak var smsSwitch: UISwitch!
    @IBOutlet weak var phoneSwitch: UISwitch!
    @IBOutlet weak var gauth: UISwitch!


    override func viewDidLoad() {
        super.viewDidLoad()
        if(AccountStore.shared.isEmailEnabled()) {
            emailSwitch.isOn = true
        }
        if(AccountStore.shared.isSMSEnabled()) {
            smsSwitch.isOn = true
        }
        if(AccountStore.shared.isPhoneEnabled()) {
            phoneSwitch.isOn = true
        }
        if(AccountStore.shared.isGauthEnabled()) {
            gauth.isOn = true
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func emailSwitched(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "email", sender: nil)
        } else {
            let twoFactor = AccountStore.shared.disableEmailTwoFactor()
            do {
                let json = try twoFactor?.getStatus()
                let status = json!["status"] as! String
                if(status == "request_code") {
                    let methods = json!["methods"] as! NSArray
                    if(methods.count > 1) {
                        self.performSegue(withIdentifier: "selectTwoFactor", sender: twoFactor)
                    } else {
                        let method = methods[0] as! String
                        let req = try twoFactor?.requestCode(method: method)
                        let status1 = try twoFactor?.getStatus()
                        let parsed1 = status1!["status"] as! String
                        if(parsed1 == "resolve_code") {
                            self.performSegue(withIdentifier: "verifyCode", sender: twoFactor)
                        }
                    }
                }
                print(json)
                print("got status")
            } catch {
                print("couldn't get status ")
            }
        }

    }

    @IBAction func smsSwitched(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "phone", sender: "sms")
        } else {

        }
    }

    @IBAction func phoneSwitched(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "phone", sender: "phone")
        } else {

        }
    }

    @IBAction func gauthSwithed(_ sender: Any) {
        let switcher = sender as! UISwitch
        if (switcher.isOn) {
            self.performSegue(withIdentifier: "gauth", sender: nil)
        } else {

        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? TwoFactorSlectorViewController {
            nextController.twoFactor = sender as! TwoFactorCall
        } else if let nextController = segue.destination as? SetPhoneViewController {
            if (sender as! String == "sms") {
                nextController.sms = true
            } else {
                nextController.phoneCall = true
            }
        }
    }

}
