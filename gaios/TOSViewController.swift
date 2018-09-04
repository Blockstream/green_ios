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


    @IBOutlet weak var nButton: UIButton!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var tosLabel: UILabel!

    @IBAction func nextButtonClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "next", sender: self)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func agreeTOSClicked(_ sender: UIButton) {
        sender.backgroundColor = UIColor.customMatrixGreen()
        sender.layer.borderColor = UIColor.customMatrixGreen().cgColor
        sender.setImage(UIImage(named: "stepIndicator"), for: UIControlState.normal)
        sender.tintColor = UIColor.white
        nButton.isUserInteractionEnabled = true
        nButton.backgroundColor = UIColor.customMatrixGreen()
        nButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL, options: [:])
        return false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        nButton.backgroundColor = UIColor.customTitaniumLight()
        nButton.isUserInteractionEnabled = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let tosString = NSMutableAttributedString(string: "I agree to the Terms of Service")
        tosString.addAttribute(.link, value: "https://www.google.com", range: NSRange(location: 15, length: 16))
        tosLabel.attributedText = tosString
        tosLabel.isUserInteractionEnabled = true
        let topString = NSMutableAttributedString(string: "GREEN is non-custodial\n Bitcoin wallet.")
        topString.setColor(color: UIColor.customMatrixGreen(), forText: "GREEN")
        topLabel.attributedText = topString
    }
}
