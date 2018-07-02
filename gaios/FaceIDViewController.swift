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
    var pinData: String = ""
    let bioID = BiometricIDAuth()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //customize
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bioID.authenticateUser { (message) in
            if(message == nil) {
                wrap { return try getSession().login(pin: self.password, pin_identifier_and_secret: self.pinData) }.done { (loginData: [String: Any]?) in
                    getGAService().loginData = loginData
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
