//
//  ToggleSettingsViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import UIKit

class ToggleSettingsViewController: UIViewController {

    var SettingsName: String = ""
    var settings: SettingsItem? = nil
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var topLabel: UILabel!

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        topLabel.text = settings?.text
        let bottomText = String(format: "Enable %@", (settings?.text)!)
        bottomLabel.text = bottomText
    }
}
