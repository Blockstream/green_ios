//
//  TermsOfServiceViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import UIKit

class TermsOfServiceViewController: UIViewController, UITextViewDelegate {

    @IBOutlet weak var termsOfService: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        termsOfService.delegate = self

        let text = termsOfService.text! as NSString

        let attributedText = termsOfService.attributedText.mutableCopy() as! NSMutableAttributedString
        attributedText.addAttribute(NSAttributedStringKey.link, value: "https://greenaddress.it/en/tos.html", range: text.range(of: "Terms of Service"))

        termsOfService.attributedText = attributedText
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        let text = termsOfService.text! as NSString
        if characterRange == text.range(of: "Terms of Service") {
            return true
        }
        return false
    }
}
