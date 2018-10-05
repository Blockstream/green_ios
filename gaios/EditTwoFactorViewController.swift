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
            //enable 2fa
        } else {
            let twoFactor = AccountStore.shared.disableEmailTwoFactor()
            do {
                let json = try twoFactor?.getStatus()
                let status = json!["status"] as! String
                if(status == "request_code") {
                    try twoFactor?.requestCode(method: "sms")
                    let json_request = try twoFactor?.getStatus()
                    let status_request = json!["status"] as! String
                    if(status_request == "resolve_code") {
                        self.performSegue(withIdentifier: "verifyCode", sender: twoFactor)
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
    }

    @IBAction func phoneSwitched(_ sender: Any) {
    }

    @IBAction func gauthSwithed(_ sender: Any) {
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

}
