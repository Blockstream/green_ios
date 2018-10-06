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
    
    let bioID = BiometricIDAuth()
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var twoFactorButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
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

    @IBAction func backButtonClicked(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
}
