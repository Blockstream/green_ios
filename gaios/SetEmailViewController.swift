//
//  SetEmailViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import UIKit
import NVActivityIndicatorView

class SetEmailViewController: UIViewController, NVActivityIndicatorViewable {


    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var getCodeButton: UIButton!
    @IBOutlet weak var buttonConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(SetEmailViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SetEmailViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        textField.attributedPlaceholder = NSAttributedString(string: "email@domainm.com",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getCodeButton.backgroundColor = UIColor.customTitaniumLight()
        textField.becomeFirstResponder()
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        getCodeButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func getCodeClicked(_ sender: Any) {
        let twoFactor = AccountStore.shared.enableEmailTwoFactor(email: self.textField.text!)
        if (twoFactor != nil) {
            wrap { try twoFactor?.getStatus()}.done{ (json: [String: Any]?) in
                let status = json!["status"] as! String
                if (status == "call") {
                    wrap { try twoFactor?.call()}.done{ _ in
                        self.performSegue(withIdentifier: "twoFactor", sender: twoFactor)
                        }.catch { error in
                            print("could't call two factor")
                    }
                } else if (status == "request_code") {
                    let methods = json!["methods"] as! NSArray
                    if(methods.count > 1) {
                        self.performSegue(withIdentifier: "twoFactorSelector", sender: twoFactor)
                    } else {
                        let method = methods[0] as! String
                        let req = try twoFactor?.requestCode(method: method)
                        let status1 = try twoFactor?.getStatus()
                        let parsed1 = status1!["status"] as! String
                        if(parsed1 == "resolve_code") {
                            self.performSegue(withIdentifier: "twoFactor", sender: twoFactor)
                        }
                    }
                }
            }.catch { error in
                print("could get two factor status")
            }
        }
    }

    func failureMessage() {
        DispatchQueue.main.async {
            NVActivityIndicatorPresenter.sharedInstance.setMessage("Login Failed")
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            self.stopAnimating()
        }
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0{
                var keyboardHeight = keyboardSize.height
                if #available(iOS 11.0, *) {
                    let bottomInset = view.safeAreaInsets.bottom
                    keyboardHeight -= bottomInset
                }
                buttonConstraint.constant += keyboardHeight
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? VerifyTwoFactorViewController {
            nextController.onboarding = true
            nextController.twoFactor = sender as! TwoFactorCall
        }
        if let nextController = segue.destination as? TwoFactorSlectorViewController {
            nextController.twoFactor = sender as! TwoFactorCall
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y != 0{
                var keyboardHeight = keyboardSize.height
                if #available(iOS 11.0, *) {
                    let bottomInset = view.safeAreaInsets.bottom
                    keyboardHeight -= bottomInset
                }
                buttonConstraint.constant -= keyboardHeight
            }
        }
    }
}
