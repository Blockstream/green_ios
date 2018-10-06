//
//  EditScreenLockSettings.swift
//  gaios
//
//  Created by Strahinja Markovic on 10/5/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class EditScreenLockSettings: UIViewController {
    @IBOutlet weak var bioAuthLabel: UILabel!
    @IBOutlet weak var bioSwitch: UISwitch!
    @IBOutlet weak var pinSwitch: UISwitch!
    let bioID = BiometricIDAuth()


    override func viewDidLoad() {
        super.viewDidLoad()
        if(self.bioID.canEvaluatePolicy()) {
            if(self.bioID.biometricType() == BiometricType.faceID) {
                bioAuthLabel.text = "Face ID"
            } else if (self.bioID.biometricType() == BiometricType.touchID) {
                bioAuthLabel.text = "Touch ID"
            }
        } else {
            bioAuthLabel.text = "Face ID / Touch ID not available"
            bioSwitch.isUserInteractionEnabled = false
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        let settings = SettingsStore.shared.getScreenLockSetting()
        if(settings == ScreenLock.None) {
            bioSwitch.isOn = false
            pinSwitch.isOn = false
        } else if (settings == ScreenLock.all) {
            bioSwitch.isOn = true
            pinSwitch.isOn = true
        } else if (settings == ScreenLock.FaceID || settings == ScreenLock.TouchID) {
            bioSwitch.isOn = true
            pinSwitch.isOn = false
        } else if (settings == ScreenLock.Pin) {
            bioSwitch.isOn = false
            pinSwitch.isOn = true
        }
    }

    @IBAction func bioAuthSwitched(_ sender: UISwitch) {
    }

    @IBAction func pinSwitched(_ sender: UISwitch) {
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
}
