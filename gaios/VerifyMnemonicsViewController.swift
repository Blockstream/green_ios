//
//  VerifyMnemonicsViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 5/30/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit
import NVActivityIndicatorView

class VerifyMnemonicsViewController: UIViewController, NVActivityIndicatorViewable {
    var wordNumbers: [UInt8] = [UInt8](repeating: 0, count: 4)
    var mnemonics:[String] = []
    var questionCounter: Int = 0
    var questionPosition: Int = 0
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var stepIndicatorView: StepIndicatorView!
    @IBOutlet weak var button0: DesignableButton!
    @IBOutlet weak var button1: DesignableButton!
    @IBOutlet weak var button2: DesignableButton!
    @IBOutlet weak var button3: DesignableButton!
    let numberOfSteps: Int = 3
    @IBOutlet weak var bottomText: UILabel!
    
    lazy var buttonsArray: Array<UIButton> = [button0, button1, button2, button3]


    override func viewDidLoad() {
        super.viewDidLoad()
        generateRandomWordNumbers()
        wordNumbers.sort { $0 < $1 }
        mnemonics = getAppDelegate().getMnemonicWords()!
        //createButtons()
        questionPosition = Int(wordNumbers[Int(arc4random_uniform(UInt32(wordNumbers.count)))])
        topLabel.text = String(format: "What is the word at position %d ?", questionPosition + 1)
        //Customization by coding:
        self.stepIndicatorView.numberOfSteps = numberOfSteps
        self.stepIndicatorView.currentStep = 0
        self.stepIndicatorView.circleColor = UIColor(red: 179.0/255.0, green: 189.0/255.0, blue: 194.0/255.0, alpha: 1.0)
        self.stepIndicatorView.circleTintColor = UIColor(red: 0.0/255.0, green: 180.0/255.0, blue: 124.0/255.0, alpha: 1.0)
        self.stepIndicatorView.circleStrokeWidth = 1.0
        self.stepIndicatorView.circleRadius = 5.0
        self.stepIndicatorView.lineColor = self.stepIndicatorView.circleColor
        self.stepIndicatorView.lineTintColor = self.stepIndicatorView.circleTintColor
        self.stepIndicatorView.lineMargin = 12.0
        self.stepIndicatorView.lineStrokeWidth = 1.0
        self.stepIndicatorView.displayNumbers = false //indicates if it displays numbers at the center instead of the core circle
        self.stepIndicatorView.direction = .leftToRight
        updateButtons()
        setSelector()
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
        } while Set(wordNumbers).count != 4
    }

    func setSelector() {
        for button in buttonsArray {
            button.addTarget(self, action:#selector(self.buttonClicked), for: .touchUpInside)
        }
    }

    func updateButtons() {
        var counter = 0
        for button in buttonsArray {
            button.setTitle(mnemonics[Int(wordNumbers[counter])], for: .normal)
            button.tag = Int(wordNumbers[counter])
            counter += 1
        }
        //questionPosition
        var rangeStart = 0
        var rangeEnd = 0
        if(questionPosition < 2) {
            rangeStart = 0
            rangeEnd = 5
        } else if (questionPosition >= 2 && questionPosition <= 21){
            rangeStart = questionPosition - 2
            rangeEnd = questionPosition + 3
        } else if (questionPosition > 21) {
            rangeEnd = 24
            rangeStart = 24 - 5
        }

        var placeHolder:String = ""
        for index in rangeStart..<rangeEnd {
            if(index == questionPosition) {
                placeHolder += "  ______   "
            } else {
                placeHolder += mnemonics[index] + " "
            }

        }
        let attributedString = NSMutableAttributedString(string: placeHolder)
        attributedString.setColor(color: UIColor.customMatrixGreen(), forText: "______")
        bottomText.attributedText = attributedString
        //range
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

    func registerAndLogin(mnemonics: String) {
        let size = CGSize(width: 30, height: 30)
        startAnimating(size, message: "Registering...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
        DispatchQueue.global(qos: .background).async {
            wrap { return try getSession().registerUser(mnemonic: mnemonics) }
                .done { _ in
                    wrap { return try getSession().login(mnemonic: mnemonics) }
                        .done { _ in
                            DispatchQueue.main.async {
                                self.stopAnimating()
                                AppDelegate.removeKeychainData()
                                Storage.wipeAll()
                                AccountStore.shared.initializeAccountStore()
                                self.performSegue(withIdentifier: "congrats", sender: self)
                            }
                        }.catch { error in
                            print("Login failed")
                            DispatchQueue.main.async() {
                                NVActivityIndicatorPresenter.sharedInstance.setMessage("Login Failed...")
                                self.stopAnimating()
                            }
                    }
                }.catch { error in
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                        NVActivityIndicatorPresenter.sharedInstance.setMessage("Register Failed...")
                    }
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                        self.stopAnimating()
                    }
                    print("register failed")
            }
        }
    }

    @objc func buttonClicked(_ sender: UIButton) {
       print("sender is ", sender.titleLabel?.text, " correct answer is ", mnemonics[questionPosition])
        if(sender.titleLabel?.text == mnemonics[questionPosition]) {
            if(questionCounter == numberOfSteps - 1) {
                guard let mnemonicWords = getAppDelegate().getMnemonicWords() else {
                    return
                }
                let stringRepresentation = mnemonicWords.joined(separator: " ") // space separated mnemonic list
                print(stringRepresentation)
                registerAndLogin(mnemonics: stringRepresentation)
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
