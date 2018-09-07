//
//  PinLoginViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/19/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit
import NVActivityIndicatorView

class PinLoginViewController: UIViewController, NVActivityIndicatorViewable {


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
        circle1.tintColor = UIColor.customTitaniumLight()
        circle2.tintColor = UIColor.customTitaniumLight()
        circle3.tintColor = UIColor.customTitaniumLight()
        circle4.tintColor = UIColor.customTitaniumLight()
        circles = [circle1, circle2, circle3, circle4]
        if (setPinMode == true) {
            topLabel.text = "Choose Pin"
        }
        //KeychainHelper.removePassword(service: "pinData", account: "user")
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
                let size = CGSize(width: 30, height: 30)
                startAnimating(size, message: "Logging in...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
                DispatchQueue.global(qos: .background).async {
                    wrap { return try getSession().loginWithPin(pin: self.pinCode, pin_data: self.pinData) }.done { _ in
                        DispatchQueue.main.async {
                            self.stopAnimating()
                            AccountStore.shared.initializeAccountStore()
                            self.performSegue(withIdentifier: "mainMenu", sender: self)
                        }
                    }.catch { error in
                        print("incorrect PIN ", error)
                        DispatchQueue.main.async {
                            NVActivityIndicatorPresenter.sharedInstance.setMessage("Login Failed")
                        }
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                            self.stopAnimating()
                            self.resetEverything()
                        }

                    }
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
                let size = CGSize(width: 30, height: 30)
                startAnimating(size, message: "Setting pin...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
                DispatchQueue.global(qos: .background).async {
                    wrap { return try getSession().setPin(mnemonic: mnemonics!, pin: self.pinCode, device: String.random(length: 10)) }
                        .done { (result: String?) in
                            guard result != nil else {
                                self.stopAnimating()
                                return
                            }
                            DispatchQueue.main.async {
                                self.stopAnimating()
                                KeychainHelper.savePassword(service: "pinData", account: "user", data: result!)
                                self.performSegue(withIdentifier: "mainMenu", sender: self)
                            }
                        }.catch { error in
                            print("setPin failed")
                            DispatchQueue.main.async {
                                NVActivityIndicatorPresenter.sharedInstance.setMessage("Setting pin failed")
                            }
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                                self.stopAnimating()
                            }
                    }
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
    
    @IBAction func backButtonClicked(_ sender: Any) {
        if(setPinMode) {
            self.navigationController?.popViewController(animated: true)
        } else {
            self.performSegue(withIdentifier: "entrance", sender: nil)
        }
    }
    func updateColor() {
        for i in 0..<counter {
            circles[i].tintColor = UIColor.customMatrixGreen()
        }
        for i in 0..<4-counter {
            circles[3-i].tintColor = UIColor.customTitaniumLight()
        }
    }
}
