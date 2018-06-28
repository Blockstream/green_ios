//
//  SendBtcDetailsViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/26/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class SendBtcDetailsViewController: UIViewController {
    
    var toAddress: String? = nil
    @IBOutlet weak var lowFeeButton: DesignableButton!
    @IBOutlet weak var mediumFeeButton: DesignableButton!
    @IBOutlet weak var highFeeButton: DesignableButton!
    
    @IBOutlet weak var amountTextField: UITextField!
    var fee: Int = 1

    @IBAction func nextButtonClicked(_ sender: UIButton) {
        self.performSegue(withIdentifier: "confirm", sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBTCConfirmationViewController {
            nextController.toAddress = toAddress
            nextController.amount = (amountTextField.text as! NSString).doubleValue
            nextController.fee = fee
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        self.view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        amountTextField.resignFirstResponder()
    }

    @IBAction func lowFeeClicked(_ sender: Any) {
        fee = 0
        lowFeeButton.backgroundColor = UIColor.customLightGray()
        lowFeeButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        mediumFeeButton.backgroundColor = UIColor.white
        mediumFeeButton.setTitleColor(UIColor.customLightGray(), for: UIControlState.normal)
        highFeeButton.backgroundColor = UIColor.white
        highFeeButton.setTitleColor(UIColor.customLightGray(), for: UIControlState.normal)
    }
    @IBAction func mediumFeeClicked(_ sender: Any) {
        fee = 1
        lowFeeButton.backgroundColor = UIColor.white
        lowFeeButton.setTitleColor(UIColor.customLightGray(), for: UIControlState.normal)
        mediumFeeButton.backgroundColor = UIColor.customLightGray()
        mediumFeeButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        highFeeButton.backgroundColor = UIColor.white
        highFeeButton.setTitleColor(UIColor.customLightGray(), for: UIControlState.normal)
    }
    @IBAction func highFeeClicked(_ sender: Any) {
        fee = 2
        lowFeeButton.backgroundColor = UIColor.white
        lowFeeButton.setTitleColor(UIColor.customLightGray(), for: UIControlState.normal)
        mediumFeeButton.backgroundColor = UIColor.white
        mediumFeeButton.setTitleColor(UIColor.customLightGray(), for: UIControlState.normal)
        highFeeButton.backgroundColor = UIColor.customLightGray()
        highFeeButton.setTitleColor(UIColor.white, for: UIControlState.normal)
    }
}
