//
//  CreateViewController.swift
//  GreenBitsIOS
//
//  Created by Goncalo Carvalho on 11/10/2017.
//  Copyright © 2017 Goncalo Carvalho. All rights reserved.
//

import UIKit

class CreateViewController: UIViewController {
    
    @IBOutlet weak var mnemonicText: UITextView!
    @IBOutlet weak var createButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mnemonicText.text = try! generateMnemonic(lang: "en")
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func agreeAction(_ sender: Any) {
        let agreeSwitch = sender as! UISwitch
        createButton.isEnabled = agreeSwitch.isOn
    }
}
