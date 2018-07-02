//
//  PinLoginViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/19/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit


class PinLoginViewController: UIViewController {


    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var circle1: UIImageView!
    @IBOutlet weak var circle2: UIImageView!
    @IBOutlet weak var circle3: UIImageView!
    @IBOutlet weak var circle4: UIImageView!
    var circles: [UIImageView] = []
    var pinCode: String = ""
    var counter: Int = 0
    var setPinMode: Bool = false
    var pinData: String = ""

    var firstPin: String = ""
    var pinConfirm: String = ""
    var firstStep: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        circle1.tintColor = UIColor.customLightGray()
        circle2.tintColor = UIColor.customLightGray()
        circle3.tintColor = UIColor.customLightGray()
        circle4.tintColor = UIColor.customLightGray()
        circles = [circle1, circle2, circle3, circle4]
        if (setPinMode == true) {
            topLabel.text = "Choose Pin"
        }
        KeychainHelper.removePassword(service: "pinData", account: "user")
    }

    @IBAction func numberClicked(_ sender: UIButton) {
        if(counter < 4) {
            counter += 1
            pinCode += (sender.titleLabel?.text)!
            print(pinCode)
            updateColor()
        }
        if (counter == 4) {
            if (setPinMode == false) {
                //login
                wrap { return try getSession().login(pin: self.pinCode, pin_identifier_and_secret: self.pinData) }.done { (loginData: [String: Any]?) in
                        getGAService().loginData = loginData
                        self.performSegue(withIdentifier: "mainMenu", sender: self)
                    }.catch { error in
                        print("incorrect PIN ", error)
                        self.resetEverything()
                    }
                return
            }
            if (firstStep) {
                firstStep = false
                firstPin = pinCode
                topLabel.text = "Confirm PIN"
                counter = 0
                pinCode = ""
                updateColor()
                return
            }
            if(firstPin == pinCode) {
                let mnemonics = getAppDelegate().getMnemonicWordsString()
                wrap { return try getSession().setPin(mnemonic: mnemonics!, pin: self.pinCode, device: String.random(length: 10)) }
                    .done { (pinData: String) in
                        KeychainHelper.savePassword(service: "pinData", account: "user", data: pinData)
                        self.performSegue(withIdentifier: "mainMenu", sender: self)
                    }.catch { error in
                        print("setPin failed")
                }
                return
            }
            firstStep = true
            topLabel.text = "Choose PIN"
            resetEverything()
            //reset notify pins are different
        }
    }
    
    func resetEverything() {
        if (setPinMode) {
            topLabel.text = "Choose PIN"
            firstStep = true
            counter = 0
            updateColor()
            pinCode = ""
            firstPin = ""
            pinConfirm = ""
        } else {
            counter = 0
            pinCode = ""
            updateColor()
        }
    }
    @IBAction func deleteClicked(_ sender: UIButton) {
        if(counter > 0) {
            pinCode.removeLast()
            print(pinCode)
            counter -= 1
            updateColor()
        }
    }
    
    func updateColor() {
        for i in 0..<counter {
            circles[i].tintColor = UIColor.customLightGreen()
        }
        for i in 0..<4-counter {
            circles[3-i].tintColor = UIColor.customLightGray()
        }
    }
}
