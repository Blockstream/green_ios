//
//  TwoFactorWarningSettings.swift
//  gaios
//
//  Created by Strahinja Markovic on 10/17/18.
//  Copyright © 2018 Blockstream.inc All rights reserved.
//

import Foundation
import UIKit

class TwoFactorWarningSettings: UIViewController {

    @IBOutlet weak var noFactorLabel: UILabel!
    @IBOutlet weak var oneFactorLabel: UILabel!
    @IBOutlet weak var noFactorSwitch: UISwitch!
    @IBOutlet weak var oneFactorSwitch: UISwitch!
    @IBOutlet weak var topLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let settings = SettingsStore.shared.getTwoFactorWarning()
        noFactorSwitch.isOn = settings.0
        oneFactorSwitch.isOn = settings.1
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func noFactorSwitched(_ sender: UISwitch) {
        SettingsStore.shared.setTwoFactorWarning(noFactor: noFactorSwitch.isOn, oneFactor: oneFactorSwitch.isOn)
    }

    @IBAction func oneFactorSwitch(_ sender: Any) {
        SettingsStore.shared.setTwoFactorWarning(noFactor: noFactorSwitch.isOn, oneFactor: oneFactorSwitch.isOn)
    }

}
