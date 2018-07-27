//
//  VerifyMnemonicsViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 5/30/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit


class VerifyMnemonicsViewController: UIViewController {
    var wordNumbers: [UInt8] = [UInt8](repeating: 0, count: 8)
    var buttonsArray: Array<UIButton> = []
    var mnemonics:[String] = []
    var questionCounter: Int = 0
    var questionPosition: Int = 0
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var stepIndicatorView: StepIndicatorView!
    

    override func viewDidLoad() {
        super.viewDidLoad()

        generateRandomWordNumbers()
        wordNumbers.sort { $0 < $1 }
        mnemonics = getAppDelegate().getMnemonicWords()!
        createButtons()
        questionPosition = Int(wordNumbers[Int(arc4random_uniform(UInt32(wordNumbers.count)))])
        topLabel.text = String(format: "What is the word at position %d ?", questionPosition + 1)
        //Customization by coding:
        self.stepIndicatorView.numberOfSteps = 5
        self.stepIndicatorView.currentStep = 0
        self.stepIndicatorView.circleColor = UIColor(red: 179.0/255.0, green: 189.0/255.0, blue: 194.0/255.0, alpha: 1.0)
        self.stepIndicatorView.circleTintColor = UIColor(red: 0.0/255.0, green: 180.0/255.0, blue: 124.0/255.0, alpha: 1.0)
        self.stepIndicatorView.circleStrokeWidth = 3.0
        self.stepIndicatorView.circleRadius = 10.0
        self.stepIndicatorView.lineColor = self.stepIndicatorView.circleColor
        self.stepIndicatorView.lineTintColor = self.stepIndicatorView.circleTintColor
        self.stepIndicatorView.lineMargin = 4.0
        self.stepIndicatorView.lineStrokeWidth = 2.0
        self.stepIndicatorView.displayNumbers = false //indicates if it displays numbers at the center instead of the core circle
        self.stepIndicatorView.direction = .leftToRight
    }

    func generateWordNumber(_ bottom: UInt8, _ top: UInt8) -> UInt8 {
        let range: UInt8 = (top - bottom) + 1
        let discard: UInt8 = 255 - 255 % range
        var randomWord: UInt8 = discard
        while randomWord >= discard {
            withUnsafeMutablePointer(to: &randomWord) { (pointer) -> Void in
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, pointer)
            }
        }
        randomWord = randomWord % range
        return randomWord + bottom
    }

    func generateRandomWordNumbers() {
        repeat {
            wordNumbers = wordNumbers.map { (_) -> UInt8 in generateWordNumber(0, 23) }
        } while Set(wordNumbers).count != 8
    }


    func createButtons(){
        let screenSize: CGRect = UIScreen.main.bounds
        let leftMargin = 20
        let betweenButtonMargin = 15
        let buttonWidth = (screenSize.width - CGFloat((leftMargin * 2 + betweenButtonMargin * 3))) / 4
        let buttonHeight = buttonWidth / 1.61
        for index in 0...7 {
            let button:UIButton = UIButton(frame: CGRect(x: 100 + index * 70, y: 400, width: 60, height: 30))
            button.backgroundColor = UIColor.customLightGreen()
            button.setTitle(mnemonics[Int(wordNumbers[index])], for: .normal)
            button.addTarget(self, action:#selector(self.buttonClicked), for: .touchUpInside)
            button.layer.cornerRadius = 5
            self.view.addSubview(button)
            button.tag = Int(wordNumbers[index])
            button.contentEdgeInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.translatesAutoresizingMaskIntoConstraints = false
            buttonsArray.append(button)
            //width & height
            NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: buttonWidth).isActive = true
            NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: buttonHeight).isActive = true
            //topConstraint
            if(index < 4) {
                NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: topLabel, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 70).isActive = true
            } else {
                NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: buttonsArray[index - 4], attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 20).isActive = true
            }
            //left constraint
            if(index % 4 == 0) {
                NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.left, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.left, multiplier: 1, constant: CGFloat(leftMargin)).isActive = true
            } else {
                NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.left, relatedBy: NSLayoutRelation.equal, toItem: buttonsArray[index - 1], attribute: NSLayoutAttribute.right, multiplier: 1, constant: CGFloat(betweenButtonMargin)).isActive = true
            }
        }
    }

    func updateButtons() {
        var counter = 0
        for button in buttonsArray {
            button.setTitle(mnemonics[Int(wordNumbers[counter])], for: .normal)
            button.tag = Int(wordNumbers[counter])
            counter += 1
        }
    }

    func updateLabels() {
        topLabel.text = String(format: "What is the word at position %d ?", questionPosition + 1)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @IBAction func touchedButton(_ sender: UIButton) {
        print(sender.tag)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @objc func buttonClicked(_ sender: UIButton) {
       print("sender is ", sender.titleLabel?.text, " correct answer is ", mnemonics[questionPosition])
        if(sender.titleLabel?.text == mnemonics[questionPosition]) {
            if(questionCounter == 4) {
                guard let mnemonicWords = getAppDelegate().getMnemonicWords() else {
                    return
                }
                let stringRepresentation = mnemonicWords.joined(separator: " ") // space separated mnemonic list
                print(stringRepresentation)
                wrap { return try getSession().registerUser(mnemonic: stringRepresentation) }
                    .done { () in
                        wrap { return try getSession().login(mnemonic: stringRepresentation) }
                            .done { (loginData: [String: Any]?) in
                                AppDelegate.removeKeychainData()
                                getGAService().loginData = loginData
                                self.performSegue(withIdentifier: "tos", sender: self)
                            }.catch { error in
                                print("Login failed")
                        }
                    }.catch { error in
                        print("register failed")
                }
            } else {
                questionCounter += 1
                stepIndicatorView.currentStep = questionCounter
                generateRandomWordNumbers()
                questionPosition = Int(wordNumbers[Int(arc4random_uniform(UInt32(wordNumbers.count)))])
                updateButtons()
                updateLabels()
            }
        } else {
            //ALERT
        }
    }

}
