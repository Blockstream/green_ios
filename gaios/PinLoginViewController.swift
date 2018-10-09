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
    @IBOutlet weak var label0: UILabel!
    @IBOutlet weak var label1: UILabel!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var label3: UILabel!
    @IBOutlet weak var label4: UILabel!
    @IBOutlet weak var label5: UILabel!
    @IBOutlet weak var attempts: UILabel!

    var pinCode: String = ""
    var pinData: String = ""
    var pinConfirm: String = ""

    var setPinMode: Bool = false
    var editPinMode: Bool = false
    var loginMode: Bool = false
    var removePinMode: Bool = false
    var confirmPin: Bool = false

    var views: Array<UIView> = Array<UIView>()
    var labels: Array<UILabel> = Array<UILabel>()
    var indicator: UIView? = nil
    var attemptsCount = 3

    override func viewDidLoad() {
        super.viewDidLoad()
        if (setPinMode == true) {
            topLabel.text = "Set a new PIN"
        }
        labels.append(contentsOf: [label0, label1, label2, label3, label4, label5])
        for label in labels {
            label.isHidden = true
        }
        attempts.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateView()
    }

    func updateAttemptsLabel() {
        attempts.text = String(format: "%d attempts remaining", attemptsCount)
        attempts.isHidden = false
    }

    func updatePinMissmatch() {
        attempts.text = "PINs must match"
        attempts.isHidden = false
    }

    @IBAction func numberClicked(_ sender: UIButton) {
        pinCode += (sender.titleLabel?.text)!
        updateView()
        if (pinCode.count < 6) {
            return
        }

        if (loginMode == true) {
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
                        self.attemptsCount -= 1
                        if(self.attemptsCount == 0) {
                            AppDelegate.removeKeychainData()
                            self.performSegue(withIdentifier: "entrance", sender: nil)
                        }
                        self.updateAttemptsLabel()
                        DispatchQueue.main.async {
                            NVActivityIndicatorPresenter.sharedInstance.setMessage("Login Failed")
                        }
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                            self.stopAnimating()
                            self.resetEverything()
                        }

                }
            }
        } else if (setPinMode == true) {
            if (confirmPin == true) {
                //set pin
                print("olla1")

                if(pinCode != pinConfirm) {
                    topLabel.text = "Set a new PIN"
                    resetEverything()
                    updatePinMissmatch()
                    print("olla2")
                    return
                }
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
                                SettingsStore.shared.setScreenLockSettings(screenLock: ScreenLock.Pin)
                                KeychainHelper.savePassword(service: "pinPassword", account: "user", data: self.pinCode)
                                KeychainHelper.savePassword(service: "pinData", account: "user", data: result!)
                                if(self.editPinMode == true) {
                                    self.navigationController?.popViewController(animated: true)
                                } else {
                                    self.performSegue(withIdentifier: "improveSecurity", sender: self)

                                }
                            }
                        }.catch { error in
                            print("setPin failed")
                            DispatchQueue.main.async {
                                NVActivityIndicatorPresenter.sharedInstance.setMessage("Setting pin failed")
                            }
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5) {
                                self.stopAnimating()
                            }
                    }
                }
                return
            }
            confirmPin = true
            pinConfirm = pinCode
            pinCode = ""
            updateView()
            //show confirm pin
            topLabel.text = "Confirm PIN"
        } else if (removePinMode == true) {
            let pass = KeychainHelper.loadPassword(service: "pinPassword", account: "user")
            if (pass == pinCode) {
                AppDelegate.removePinKeychainData()
                let settings = SettingsStore.shared.getScreenLockSetting()
                if (settings == ScreenLock.Pin) {
                    SettingsStore.shared.setScreenLockSettings(screenLock: ScreenLock.None)
                } else if (settings == ScreenLock.all) {
                    let bioID = BiometricIDAuth()
                    if (bioID.biometricType() == BiometricType.faceID) {
                        SettingsStore.shared.setScreenLockSettings(screenLock: ScreenLock.FaceID)
                    } else if (bioID.biometricType() == BiometricType.touchID) {
                        SettingsStore.shared.setScreenLockSettings(screenLock: ScreenLock.TouchID)
                    }
                }
            }
            self.navigationController?.popViewController(animated: true)
            return
        }
    }

    func resetEverything() {
        pinCode = ""
        updateView()
    }

    func updateView() {
        var index = 0
        for char in pinCode {
            labels[index].text = String(char)
            labels[index].isHidden = false
            index += 1
        }
        createIndicator(position: pinCode.count)
        for i in index..<labels.count {
            labels[i].isHidden = true
        }
    }

    func createIndicator(position: Int) {
        if (position >= 6) {
            indicator?.isHidden = true
            return
        }
        indicator?.layer.removeAllAnimations()
        indicator?.removeFromSuperview()
        let labelP = labels[position]
        indicator = UIView()
        indicator?.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        indicator?.backgroundColor = UIColor.customMatrixGreen()
        indicator?.translatesAutoresizingMaskIntoConstraints = false
        indicator?.alpha = 1.0;
        self.view.addSubview(indicator!)
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 0, constant: 2).isActive = true
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 0, constant: 21).isActive = true
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: labelP, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: labelP, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0).isActive = true
        UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse], animations: {

            self.indicator?.alpha = 0.0

        }, completion: nil)
    }

    @IBAction func deleteClicked(_ sender: UIButton) {
        if(pinCode.count > 0) {
            pinCode.removeLast()
            updateView()
            print(pinCode)
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        if(setPinMode || editPinMode) {
            self.navigationController?.popViewController(animated: true)
        } else {
            self.performSegue(withIdentifier: "entrance", sender: nil)
        }
    }
}
