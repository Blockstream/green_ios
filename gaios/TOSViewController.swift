//
//  TOSViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/28/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class TOSViewController: UIViewController {

    
    @IBOutlet weak var nextButton: UIButton!
    var tosClicked: Bool = false
    var recoveryClicked: Bool = false

    @IBAction func nextButtonClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "security", sender: self)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func agreeTOSClicked(_ sender: UIButton) {
        tosClicked = true
        sender.backgroundColor = UIColor.customMatrixGreen()
        sender.layer.borderColor = UIColor.customMatrixGreen().cgColor
        sender.setImage(UIImage(named: "stepIndicator"), for: UIControlState.normal)
        sender.tintColor = UIColor.white
        if tosClicked && recoveryClicked {
            nextButton.isUserInteractionEnabled = true
            nextButton.backgroundColor = UIColor.customLightGreen()
        }
    }

    @IBAction func savedRecoverySeedClicked(_ sender: UIButton) {
        recoveryClicked = true
        sender.backgroundColor = UIColor.customMatrixGreen()
        sender.layer.borderColor = UIColor.customMatrixGreen().cgColor
        sender.setImage(UIImage(named: "stepIndicator"), for: UIControlState.normal)
        sender.tintColor = UIColor.white
        if tosClicked && recoveryClicked {
            nextButton.isUserInteractionEnabled = true
            nextButton.backgroundColor = UIColor.customMatrixGreen()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        nextButton.isUserInteractionEnabled = false
        nextButton.backgroundColor = UIColor.customLightGray()
    }
}
