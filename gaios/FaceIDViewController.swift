//
//  FaceIDViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/30/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit
import NVActivityIndicatorView

class FaceIDViewController: UIViewController, NVActivityIndicatorViewable {
    
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
                let size = CGSize(width: 30, height: 30)
                self.startAnimating(size, message: "Logging in...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
                DispatchQueue.global(qos: .background).async {
                   /* wrap { return try getSession().login(pin: self.password, pin_identifier: self.pinIdentifier, pin_secret: self.pinSecret) }.done { (loginData: [String: Any]?) in
                        DispatchQueue.main.async {
                            getGAService().loginData = loginData
                            AccountStore.shared.initializeAccountStore()
                            self.performSegue(withIdentifier: "mainMenu", sender: self)
                        }
                    }.catch { error in
                        print("incorrect PIN ", error)
                        DispatchQueue.main.async {
                            NVActivityIndicatorPresenter.sharedInstance.setMessage("Login Failed")
                        }
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                            self.stopAnimating()
                        }
                    }*/
                }
            } else {
                //error
            }
        }
    }
}
