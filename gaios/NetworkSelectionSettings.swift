//
//  NetworkSelectionSettings.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import UIKit

class NetworkSelectionSettings: UIViewController, UITextFieldDelegate {
    
    
    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var ipTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var portTextField: UITextField!
    @IBOutlet weak var mainnetIndicator: UIView!
    @IBOutlet weak var testnetIndicator: UIView!
    @IBOutlet weak var liquidIndicator: UIView!
    
    @IBOutlet weak var mainnetSelector: DesignableView!
    @IBOutlet weak var testnetSelector: DesignableView!
    @IBOutlet weak var liquidSelector: DesignableView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ipTextField.delegate = self
        passwordTextField.delegate = self
        portTextField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(NetworkSelectionSettings.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(NetworkSelectionSettings.keyboardWillHide), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        ipTextField.attributedPlaceholder = NSAttributedString(string: "IP address",
                                                               attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        passwordTextField.attributedPlaceholder = NSAttributedString(string: "Password",
                                                               attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        portTextField.attributedPlaceholder = NSAttributedString(string: "Port number",
                                                               attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        let gesture = UITapGestureRecognizer(target: self, action:  #selector (self.mainnetSelected (_:)))
        mainnetSelector.addGestureRecognizer(gesture)
        let gesture1 = UITapGestureRecognizer(target: self, action:  #selector (self.testnetSelected (_:)))
        testnetSelector.addGestureRecognizer(gesture1)
        let gesture2 = UITapGestureRecognizer(target: self, action:  #selector (self.liquidSelected (_:)))
        liquidSelector.addGestureRecognizer(gesture2)
        let network = getNetwork()
        if (network == Network.TestNet) {
            mainnetIndicator.isHidden = true
            testnetIndicator.isHidden = false
            liquidIndicator.isHidden = true
        }
        
    }
    
    @objc func mainnetSelected(_ sender:UITapGestureRecognizer){
        mainnetIndicator.isHidden = false
        testnetIndicator.isHidden = true
        liquidIndicator.isHidden = true
    }
    
    @objc func testnetSelected(_ sender:UITapGestureRecognizer){
        mainnetIndicator.isHidden = true
        testnetIndicator.isHidden = false
        liquidIndicator.isHidden = true
    }
    
    @objc func liquidSelected(_ sender:UITapGestureRecognizer){
        mainnetIndicator.isHidden = true
        testnetIndicator.isHidden = true
        liquidIndicator.isHidden = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        topConstraint.constant = 200
        setupView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layoutIfNeeded()
        saveButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func saveButtonClicked(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {

            let animations = { [weak self] in
                self?.topConstraint.constant -= keyboardSize.height
                self?.topConstraint.constant -= 1
            }
            let options = UIViewKeyframeAnimationOptions.beginFromCurrentState
            UIView.animateKeyframes(withDuration: 0.5, delay: 0, options: options, animations: animations, completion: nil)

        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            let animations = { [weak self] in
                self?.topConstraint.constant = 200
                self?.topConstraint.constant = 200

            }
            let options = UIViewKeyframeAnimationOptions.beginFromCurrentState
            UIView.animateKeyframes(withDuration: 0.5, delay: 0, options: options, animations: animations, completion: nil)
        }
    }
    
    func setupView() {
        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    }
}
