//
//  FaceIDViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import UIKit
import NVActivityIndicatorView

class FaceIDViewController: UIViewController, NVActivityIndicatorViewable {
    
    var password: String = ""
    var pinData: String = ""
    let bioID = BiometricIDAuth()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //customize
    }
    
    @IBAction func backButtonClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "entrance", sender: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.layoutIfNeeded()
        self.view.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    func authenticate() {
        bioID.authenticateUser { (message) in
            if(message == nil) {
                let size = CGSize(width: 30, height: 30)
                self.startAnimating(size, message: "Logging in...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
                DispatchQueue.global(qos: .background).async {
                    wrap { return try getSession().loginWithPin(pin: self.password, pin_data: self.pinData) }.done { _ in
                        DispatchQueue.main.async {
                            self.stopAnimating()
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
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.7) {
                    if (self.isViewLoaded && (self.view.window != nil)) {
                        self.authenticate()
                    }
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        authenticate()
    }
}
