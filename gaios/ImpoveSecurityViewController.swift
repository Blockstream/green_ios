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
    
    @IBOutlet weak var faceIDButton: UIButton!
    let bioID = BiometricIDAuth()
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var pinButton: UIButton!
    @IBOutlet weak var twoFactorButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
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
        pinButton.contentHorizontalAlignment = .left
        faceIDButton.contentHorizontalAlignment = .left
        skipButton.contentHorizontalAlignment = .left
        twoFactorButton.contentHorizontalAlignment = .left
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

    @IBAction func backButtonClicked(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func faceIDButtonClicked(_ sender: Any) {
        bioID.authenticateUser { (message) in
            if(message == nil) {
                let password = String.random(length: 14)
                let deviceid = String.random(length: 14)
                let mnemonics = getAppDelegate().getMnemonicWordsString()
                wrap { return try getSession().setPin(mnemonic: mnemonics!, pin: password, device: deviceid) }
                    .done { (result: String?) in
                        guard result != nil else {
                            return
                        }
                        KeychainHelper.savePassword(service: "password", account: "user", data: password)
                        KeychainHelper.savePassword(service: "pinData", account: "user", data: result!)
                        self.performSegue(withIdentifier: "mainMenu", sender: self)
                    }.catch { error in
                        print("setPin failed")
                }
            } else {
                
            }
        }
    }
    
}
