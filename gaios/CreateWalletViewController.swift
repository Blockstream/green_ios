//
//  CreateWalletViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 5/31/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class CreateWalletViewController: UIViewController {
    
    @IBOutlet weak var topLabel: UILabel!
    var viewArray: Array<UIView> = []
    var mnemonics:[String] = []
    @IBOutlet weak var nextButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        if getAppDelegate().getMnemonicWords() == nil {
            getAppDelegate().setMnemonicWords(try! generateMnemonic(lang: "en").components(separatedBy: " "))
        }
        mnemonics = getAppDelegate().getMnemonicWords()!
        createViews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        nextButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    func createViews() {
        let screenSize: CGRect = UIScreen.main.bounds
        let viewWidth = (screenSize.width - 40) / 4
        let viewHeight = viewWidth / 1.61

        for index in 0...23 {
            let myView = UIView(frame: CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
            myView.translatesAutoresizingMaskIntoConstraints = false
            myView.borderWidth = 1
            myView.borderColor = UIColor.customLightGray()
            viewArray.append(myView)
            //index label
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
            label.textAlignment = .center
            label.text = String(index + 1)
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = UIColor.customLightGray()
            label.translatesAutoresizingMaskIntoConstraints = false
            myView.addSubview(label)
            NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: myView, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
            NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: myView, attribute: NSLayoutAttribute.top, multiplier: 1, constant: 4).isActive = true
            NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: myView, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 0).isActive = true
            
            //mnemonic label
            let menmonicLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
            menmonicLabel.textAlignment = .center
            menmonicLabel.text = mnemonics[index]
            menmonicLabel.font = UIFont.systemFont(ofSize: 16)
            menmonicLabel.textColor = UIColor.customLightGray()
            menmonicLabel.translatesAutoresizingMaskIntoConstraints = false
            myView.addSubview(menmonicLabel)
            NSLayoutConstraint(item: menmonicLabel, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: myView, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
            NSLayoutConstraint(item: menmonicLabel, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: myView, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 4).isActive = true
            NSLayoutConstraint(item: menmonicLabel, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: myView, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 0).isActive = true

            self.view.addSubview(myView)
            //left constraint
            NSLayoutConstraint(item: myView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: viewWidth).isActive = true
            NSLayoutConstraint(item: myView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: viewHeight).isActive = true
            if(index == 0 || index % 4 == 0) {
                NSLayoutConstraint(item: myView, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 20).isActive = true
            } else {
                NSLayoutConstraint(item: myView, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: viewArray[index - 1], attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: -1).isActive = true
            }
            //top constraint
            if (index < 4) {
                NSLayoutConstraint(item: myView, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: topLabel, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 40).isActive = true
            } else {
                NSLayoutConstraint(item: myView, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: viewArray[index - 4], attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -1).isActive = true
            }
            

        }
   
    }
}
