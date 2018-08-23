//
//  VerifyTwoFactorViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 8/9/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class VerifyTwoFactorViewController: UIViewController {

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var buttonConstraint: NSLayoutConstraint!
    @IBOutlet weak var confirmButton: UIButton!
    var twoFactor: TwoFactorCall? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(VerifyTwoFactorViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(VerifyTwoFactorViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        confirmButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }
    
    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func confirmButtonClicked(_ sender: Any) {
        wrap { try self.twoFactor?.resolveCode(code: self.textField.text!)}.done{ _ in
            print("email activated")
            self.performSegue(withIdentifier: "mainView", sender: nil)
            }.catch { error in
            print("something went wrong with validating pin?")
        }
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if buttonConstraint.constant == 0{
                var keyboardHeight = keyboardSize.height
                if #available(iOS 11.0, *) {
                    let bottomInset = view.safeAreaInsets.bottom
                    keyboardHeight -= bottomInset
                }
                buttonConstraint.constant += keyboardHeight
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if buttonConstraint.constant != 0{
                buttonConstraint.constant = 0
            }
        }
    }

}
