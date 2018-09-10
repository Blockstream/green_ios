//
//  CongratsViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 8/8/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class CongratsViewController: UIViewController {
    
    @IBOutlet weak var topButton: UIButton!
    @IBOutlet weak var bottomButton: UIButton!
    @IBOutlet weak var topLabel: UILabel!
    let bioID = BiometricIDAuth()

    override func viewDidLoad() {
        super.viewDidLoad()
        let text = NSAttributedString(string: "Congrats!\n You are now a \n proud owner of \n Bitcoin wallet.")
        topLabel.attributedText = text
        if(bioID.canEvaluatePolicy()){
            if(bioID.biometricType() == BiometricType.faceID) {
                topButton.setTitle("Enable Face ID", for: UIControlState.normal)
            } else if (bioID.biometricType() == BiometricType.touchID) {
                topButton.setTitle("Enabe Touch ID", for: UIControlState.normal)
            } else {
                topButton.isUserInteractionEnabled = false
                topButton.backgroundColor = UIColor.customTitaniumLight()
                topButton.setTitle("Touch/Face ID not available", for: UIControlState.normal)
            }
        } else {
            topButton.isUserInteractionEnabled = false
            topButton.backgroundColor = UIColor.customTitaniumLight()
            topButton.setTitle("Touch/Face ID not available", for: UIControlState.normal)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        topButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let pinController = segue.destination as? PinLoginViewController {
            pinController.setPinMode = true
        }
    }

    @IBAction func EnableBioClicked(_ sender: Any) {
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
                        if(self.bioID.canEvaluatePolicy()) {
                            if(self.bioID.biometricType() == BiometricType.faceID) {
                                SettingsStore.shared.setScreenLockSettings(screenLock: ScreenLock.FaceID)
                            } else if (self.bioID.biometricType() == BiometricType.touchID) {
                                SettingsStore.shared.setScreenLockSettings(screenLock: ScreenLock.TouchID)
                            }
                        }
                        KeychainHelper.savePassword(service: "password", account: "user", data: password)
                        KeychainHelper.savePassword(service: "pinData", account: "user", data: result!)
                        self.performSegue(withIdentifier: "mainMenu", sender: self)
                    }.catch { error in
                        print("setPin failed")
                }
            } else {
                //here?
            }
        }
    }
}
