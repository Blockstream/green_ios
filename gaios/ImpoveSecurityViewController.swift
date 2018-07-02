//
//  ImpoveSecurityViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/28/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class ImproveSecurityViewController: UIViewController {
    
    @IBOutlet weak var topLabel: DesignableLabel!
    @IBOutlet weak var faceIDButton: UIButton!
    let bioID = BiometricIDAuth()

    override func viewDidLoad() {
        super.viewDidLoad()
        topLabel.padding = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 50)
        if(bioID.canEvaluatePolicy()){
            if(bioID.biometricType() == BiometricType.faceID) {
                faceIDButton.setTitle("Use Face ID to protect wallet", for: UIControlState.normal)
            } else if (bioID.biometricType() == BiometricType.touchID) {
                faceIDButton.setTitle("Use Touch ID to protect wallet", for: UIControlState.normal)
            } else {
                faceIDButton.isUserInteractionEnabled = false
                faceIDButton.setTitle("Touch/Face ID not available", for: UIControlState.normal)
            }
        } else {
            faceIDButton.isUserInteractionEnabled = false
            faceIDButton.setTitle("Touch/Face ID not available", for: UIControlState.normal)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let pinController = segue.destination as? PinLoginViewController {
            pinController.setPinMode = true
        }
    }

    @IBAction func skipButtonClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "mainMenu", sender: self)
    }
    
    @IBAction func setPinClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "setPin", sender: self)
    }
    
    @IBAction func faceIDButtonClicked(_ sender: Any) {
        bioID.authenticateUser { (message) in
            if(message == nil) {
                let password = String.random(length: 14)
                let deviceid = String.random(length: 14)
                let mnemonics = getAppDelegate().getMnemonicWordsString()
                wrap { return try getSession().setPin(mnemonic: mnemonics!, pin: password, device: deviceid) }
                    .done { (pinData: String) in
                        KeychainHelper.savePassword(service: "password", account: "user", data: password)
                        KeychainHelper.savePassword(service: "pinData", account: "user", data: pinData)
                        self.performSegue(withIdentifier: "mainMenu", sender: self)
                    }.catch { error in
                        print("setPin failed")
                }
            } else {
                
            }
        }
    }
    
}
