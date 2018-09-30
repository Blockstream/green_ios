//
//  EnableTwoFactorViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 9/27/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class EnableTwoFactorViewController : UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }

    @IBAction func phoneCallClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "phone", sender: "call")
    }

    @IBAction func smsClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "phone", sender: "sms")
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

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

}
