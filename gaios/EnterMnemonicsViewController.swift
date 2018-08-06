//
//  EnterMnemonicsViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class EnterMnemonicsViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var topLabel: UILabel!
    var textFiels:[UITextField] = []
    var box:UIView = UIView()
    var constraint: NSLayoutConstraint? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        createUI()
        NotificationCenter.default.addObserver(self, selector: #selector(EnterMnemonicsViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(EnterMnemonicsViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        doneButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func doneButtonClicked(_ sender: Any) {
       //let _ = mnemonicWords.joined(separator: " ")
        let trimmedUserProvidedMnemonic = getNetwork() == Network.LocalTest ? "cotton slot artwork now grace assume syrup route moment crisp cargo sock wrap duty craft joy adult typical nut mad way autumn comic silent".trimmingCharacters(in: .whitespacesAndNewlines) : "current tomato armed onion able case donkey summer shrimp ridge into keen motion parent twin mobile paper member satisfy gather crane soft genuine produce".trimmingCharacters(in: .whitespacesAndNewlines)
       // let trimmedUserProvidedMnemonic = getNetwork() == Network.LocalTest ? "cotton slot artwork now grace assume syrup route moment crisp cargo sock wrap duty craft joy adult typical nut mad way autumn comic silent".trimmingCharacters(in: .whitespacesAndNewlines) : "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive spike pond industry time hero trim verb mammal asthma".trimmingCharacters(in: .whitespacesAndNewlines)
        retry(session: getSession(), network: getNetwork()) {
            wrap { return try getSession().login(mnemonic: trimmedUserProvidedMnemonic) }
            }.done { (loginData: [String: Any]?) in
                getGAService().loginData = loginData
                AccountStore.shared.initializeAccountStore()
                self.performSegue(withIdentifier: "mainMenu", sender: self)
            }.catch { error in
                print("Login failed")
        }
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            //box.frame.origin.y = self.view.frame.height - keyboardSize.height - box.frame.height
          /*  view.removeConstraint(constraint!)
            let viewheight = self.view.frame.height
            let keyheight = keyboardSize.height
            let boxh = box.frame.height
            print("viewh = ", viewheight, " keyHeight = ", keyheight, " boxh = ", boxh)
            constraint = NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -keyboardSize.height)
            constraint?.isActive = true*/
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {

        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    func createBlock(number: Int) -> UIView {
        let numberString = String(format: "%d", number+1) //loop start with 0, ui starts with 1
        let block:UIView = UIView()
        block.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        block.translatesAutoresizingMaskIntoConstraints = false

        let label: UILabel = UILabel()
        label.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        label.text = numberString
        label.textColor = UIColor.customMatrixGreen()
        label.translatesAutoresizingMaskIntoConstraints = false
        block.addSubview(label)
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 14).isActive = true
        let size = label.sizeThatFits(CGSize(width: 25, height: 15))
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.lessThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: size.width).isActive = true

        let textField: TextField = TextField()
        textField.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.borderStyle = .none
        textField.textColor = UIColor.white
        textField.autocorrectionType = .no
        textField.adjustsFontSizeToFitWidth = true
        textField.delegate = self
        block.addSubview(textField)
        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: label, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: 5).isActive = true
        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: -5).isActive = true
        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -1).isActive = true
        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 30).isActive = true

        let bottomLine:UIView = UIView()
        bottomLine.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        bottomLine.backgroundColor = UIColor.customTitaniumMedium()
        block.addSubview(bottomLine)
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 1).isActive = true
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: label, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: 5).isActive = true
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: -5).isActive = true

        return block
    }

    func createUI() {
        let blockWidth = (view.frame.width - 32) / 4
        box.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        box.translatesAutoresizingMaskIntoConstraints = false
        let height = 360
        view.addSubview(box)
        NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.width, multiplier: 0, constant: view.frame.width).isActive = true
        NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: CGFloat(height)).isActive = true
        constraint = NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: topLabel, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 40)
        constraint!.isActive = true
        NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 0).isActive = true

        for index in 0..<24 {
            print(index)
            let row:Int = index / 4
            let block = createBlock(number: index)
            box.addSubview(block)

            let leadingConstant:CGFloat = CGFloat(16 + CGFloat(index % 4) * blockWidth)
            let topConstant:CGFloat = CGFloat(row * 60)

            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 0, constant: blockWidth).isActive = true
            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 45).isActive = true
            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: box, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: leadingConstant).isActive = true
            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: box, attribute: NSLayoutAttribute.top, multiplier: 1, constant: topConstant).isActive = true
            //add constraints tp block
        }
    }
}
