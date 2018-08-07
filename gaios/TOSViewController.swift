//
//  TOSViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/28/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class TOSViewController: UIViewController {


    @IBOutlet weak var nextButton: UIButton!
    var tosClicked: Bool = false
    var recoveryClicked: Bool = false
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var tosLabel: UILabel!

    @IBAction func nextButtonClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "next", sender: self)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func agreeTOSClicked(_ sender: UIButton) {
        tosClicked = true
        sender.backgroundColor = UIColor.customMatrixGreen()
        sender.layer.borderColor = UIColor.customMatrixGreen().cgColor
        sender.setImage(UIImage(named: "stepIndicator"), for: UIControlState.normal)
        sender.tintColor = UIColor.white
        if tosClicked && recoveryClicked {
            nextButton.isUserInteractionEnabled = true
            nextButton.backgroundColor = UIColor.customLightGreen()
            nextButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])

        }
    }

    @IBAction func savedRecoverySeedClicked(_ sender: UIButton) {
        recoveryClicked = true
        sender.backgroundColor = UIColor.customMatrixGreen()
        sender.layer.borderColor = UIColor.customMatrixGreen().cgColor
        sender.setImage(UIImage(named: "stepIndicator"), for: UIControlState.normal)
        sender.tintColor = UIColor.white
        if tosClicked && recoveryClicked {
            nextButton.isUserInteractionEnabled = true
            nextButton.backgroundColor = UIColor.customMatrixGreen()
            nextButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
        }
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL, options: [:])
        return false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        nextButton.isUserInteractionEnabled = false
        nextButton.backgroundColor = UIColor.customLightGray()
        let tosString = NSMutableAttributedString(string: "I agree to the Terms of Service")
        tosString.addAttribute(.link, value: "https://www.google.com", range: NSRange(location: 15, length: 16))
        tosLabel.attributedText = tosString
        tosLabel.isUserInteractionEnabled = true
        let topString = NSMutableAttributedString(string: "GREEN is non-custodial\n Bitcoin wallet.")
        topString.setColor(color: UIColor.customMatrixGreen(), forText: "GREEN")
        topLabel.attributedText = topString
    }
}
