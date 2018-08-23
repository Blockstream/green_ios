//
//  SetEmailViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 8/8/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit
import NVActivityIndicatorView

class SetEmailViewController: UIViewController, NVActivityIndicatorViewable {


    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var getCodeButton: UIButton!
    @IBOutlet weak var buttonConstraint: NSLayoutConstraint!
    var emailFactor: TwoFactorCall? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(SetEmailViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SetEmailViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getCodeButton.backgroundColor = UIColor.customLightGray()
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
        DispatchQueue.global(qos: .background).async {
            wrap { return try getSession().getTwoFactorConfig() }.done { (config: [String: Any]?) in
                wrap { try getSession().setEmail(email: self.textField.text!)}.done { (twoFactor: TwoFactorCall) in
                    DispatchQueue.main.async {
                        self.emailFactor = twoFactor
                        self.stopAnimating()
                        print("done")
                        self.performSegue(withIdentifier: "code", sender: nil)
                    }
                }.catch { error in
                    self.failureMessage()
                }
            }.catch { error in
                self.failureMessage()
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
            nextController.twoFactor = emailFactor
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
