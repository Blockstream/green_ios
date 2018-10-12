//
//  WelcomeBackViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import UIKit

class WelcomeBackViewController: UIViewController {

    let bioID = BiometricIDAuth()

    @IBOutlet weak var topButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if(bioID.canEvaluatePolicy()){
            if(bioID.biometricType() == BiometricType.faceID) {
                topButton.setTitle("Enable Face ID", for: UIControlState.normal)
                topButton.layoutIfNeeded()
                topButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
            } else if (bioID.biometricType() == BiometricType.touchID) {
                topButton.setTitle("Enabe Touch ID", for: UIControlState.normal)
                topButton.layoutIfNeeded()
                topButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? PinLoginViewController {
            nextController.restoreMode = true
            nextController.setPinMode = true
        }
    }

    @IBAction func bioAuthenticateClicked(_ sender: Any) {
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
                        KeychainHelper.savePassword(service: "bioPassword", account: "user", data: password)
                        KeychainHelper.savePassword(service: "bioData", account: "user", data: result!)
                        self.performSegue(withIdentifier: "mainMenu", sender: self)
                    }.catch { error in
                        print("setPin failed")
                }
            } else {
                //here?
            }
        }
    }

    @IBAction func setPinClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "pin", sender: nil)
    }

}
