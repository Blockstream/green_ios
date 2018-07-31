//
//  FaceIDViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/30/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class FaceIDViewController: UIViewController {
    
    var password: String = ""
    var pinIdentifier: String = ""
    var pinSecret: String = ""
    let bioID = BiometricIDAuth()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //customize
    }
    
    @IBAction func backButtonClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "entrance", sender: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bioID.authenticateUser { (message) in
            if(message == nil) {
                wrap { return try getSession().login(pin: self.password, pin_identifier: self.pinIdentifier, pin_secret: self.pinSecret) }.done { (loginData: [String: Any]?) in
                    getGAService().loginData = loginData
                    AccountStore.shared.initializeAccountStore()
                    self.performSegue(withIdentifier: "mainMenu", sender: self)
                    }.catch { error in
                        print("incorrect PIN ", error)
                }
            } else {
                //error
            }
        }
    }
}
