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
    var pageCounter:Int = 0;
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var word1: UILabel!
    @IBOutlet weak var word2: UILabel!
    @IBOutlet weak var word3: UILabel!
    @IBOutlet weak var word4: UILabel!
    @IBOutlet weak var word5: UILabel!
    @IBOutlet weak var word6: UILabel!
    lazy var arrayLabels: [UILabel] = [self.word1, self.word2, self.word3, self.word4, self.word5, self.word6]

    @IBOutlet weak var indicatorView: UIView!
    var indicatorBoxes: Array<UIView> = []
    var indicatorLayers: Array<CAGradientLayer> = []
    var widths: Array<Int>  = []

    override func viewDidLoad() {
        super.viewDidLoad()
        if getAppDelegate().getMnemonicWords() == nil {
            getAppDelegate().setMnemonicWords(try! generateMnemonic(lang: "en").components(separatedBy: " "))
        }
        mnemonics = getAppDelegate().getMnemonicWords()!
        //createViews()
        let maxWidth = self.view.frame.width - 50 - 60
        let width = maxWidth / 6
        widths = generateAllWidths(maxWidth: Int(maxWidth), blockWidth: Int(width))
        createIndicators()
        loadWords()
    }

    func createIndicators() {
        let height = 10
        for index in 0..<24 {
            let row = index / 6
            let position = index % 6
            let box = UIView()
            box.frame = CGRect(x: 0, y: 0, width: widths[index], height: height)
            box.backgroundColor = UIColor.clear
            box.borderWidth = 1
            box.borderColor = UIColor.customMatrixGreen()
            box.translatesAutoresizingMaskIntoConstraints = false
            indicatorBoxes.append(box)
            indicatorView.addSubview(box)
            if (row == 0) {
                NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: indicatorView, attribute: NSLayoutAttribute.top, multiplier: 1, constant: 0).isActive = true
            } else {
                NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: indicatorBoxes[index - 6], attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 15).isActive = true
            }
            if (position == 0) {
                NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: indicatorView, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 0).isActive = true
            } else {
                NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: indicatorBoxes[index - 1], attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: 10).isActive = true
            }
            NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: CGFloat(widths[index])).isActive = true
            NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: CGFloat(height)).isActive = true
            //width height
        }
    }

    func generateAllWidths(maxWidth: Int, blockWidth: Int) -> Array<Int> {
        var tmp: Array<Int> = []
        for _ in 0..<4 {
            tmp.append(contentsOf: generateWidthsForRow(maxWidth: maxWidth, blockWidth: blockWidth))
        }
        return tmp
    }

    func generateWidthsForRow(maxWidth: Int, blockWidth: Int) -> Array<Int>{
        var tmp: Array<Int> = []
        var sum = maxWidth + 1
        while (sum > maxWidth) {
            sum = 0
            tmp.removeAll()
            for _ in 0..<6 {
                let width = randomNumber(MIN: blockWidth - 15, MAX: blockWidth + 15)
                tmp.append(width)
                sum += width
            }
        }
        return tmp
    }

    func randomNumber(MIN: Int, MAX: Int)-> Int{
        var list : [Int] = []
        for i in MIN...MAX {
            list.append(i)
        }
        return list[Int(arc4random_uniform(UInt32(list.count)))]
    }

    func animateRow(row: Int) {
        let start = row * 6
        var column = 0
            for index in start..<start+6 {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(column * 500)) {
                    self.animateColorChange(abc: self.indicatorBoxes[index])
                }
                column += 1
            }
    }

    func animateBackwardsRow(row: Int) {
        var column = 0
        let count = indicatorLayers.count
        let start = count - 6 > 0 ? count - 6 : 0
        for index in start..<count {
            indicatorLayers[index].removeFromSuperlayer()
            column += 1
        }
        for _ in start..<count {
            indicatorLayers.removeLast()
        }
    }

    func animateColorChange(abc: UIView) {

        let startLocations = [0, 0]
        let endLocations = [1, 2]

        let layer = CAGradientLayer()
        layer.colors = [UIColor.customMatrixGreen().cgColor, UIColor.clear.cgColor]
        layer.frame = abc.bounds
        layer.locations = startLocations as [NSNumber]
        layer.startPoint = CGPoint(x: 0.0, y: 1.0)
        layer.endPoint = CGPoint(x: 1.0, y: 1.0)
        abc.layer.addSublayer(layer)
        indicatorLayers.append(layer)

        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = startLocations
        anim.toValue = endLocations
        anim.duration = 0.5
        layer.add(anim, forKey: "loc")
        layer.locations = endLocations as [NSNumber]
    }

    func animateColorChangeBackwards(abc: UIView) {

        let endLocations = [0, 0]
        let startLocations = [1, 2]

        let layer = CAGradientLayer()
        layer.colors = [UIColor.customTitaniumDark().cgColor, UIColor.customTitaniumDark().cgColor]
        layer.frame = abc.bounds
        layer.locations = startLocations as [NSNumber]
        layer.endPoint = CGPoint(x: 0.0, y: 1.0)
        layer.startPoint = CGPoint(x: 1.0, y: 1.0)
        abc.layer.addSublayer(layer)
        indicatorLayers.append(layer)

        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = endLocations
        anim.toValue = startLocations
        anim.duration = 0.5
        layer.add(anim, forKey: "loc")
        layer.locations = endLocations as [NSNumber]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateRow(row: 0)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        nextButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func nextButtonClicked(_ sender: Any) {
        if (pageCounter == 3) {
            self.performSegue(withIdentifier: "next", sender: nil)
        } else {
            pageCounter += 1
            animateRow(row: pageCounter)
            loadWords()
        }
    }

    func loadWords() {
        let start = pageCounter * 6
        let end = start + 6
        for index in start..<end {
            let real = index+1
            let formattedString = NSMutableAttributedString(string: String(format: "%d. %@", real, mnemonics[index]))
            formattedString.setColor(color: UIColor.customMatrixGreen(), forText: String(format: "%d.", real))
            arrayLabels[index % 6].attributedText = formattedString
            arrayLabels[index % 6].sizeToFit()
        }
     }

    @IBAction func backButtonClicked(_ sender: Any) {
        if(pageCounter == 0) {
            navigationController?.popViewController(animated: true)
        } else {
            animateBackwardsRow(row: pageCounter)
            pageCounter -= 1
            loadWords()
        }
    }

    func createViews() {
        let screenSize: CGRect = UIScreen.main.bounds
        let viewWidth = (screenSize.width - 40) / 4
        let viewHeight = viewWidth / 1.61

        for index in 0...23 {
            let myView = UIView(frame: CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
            myView.translatesAutoresizingMaskIntoConstraints = false
            myView.borderWidth = 1
            myView.borderColor = UIColor.customTitaniumLight()
            viewArray.append(myView)
            //index label
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
            label.textAlignment = .center
            label.text = String(index + 1)
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = UIColor.customTitaniumLight()
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
            menmonicLabel.textColor = UIColor.customTitaniumLight()
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
