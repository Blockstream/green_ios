//
//  TwoFactorSelectorViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import UIKit

class TwoFactorSlectorViewController: UIViewController {

    var twoFactor: TwoFactorCall? = nil
    @IBOutlet weak var firstButton: UIButton!
    @IBOutlet weak var secondButton: UIButton!
    @IBOutlet weak var thirdButton: UIButton!
    @IBOutlet weak var fourthButton: UIButton!
    @IBOutlet weak var firstImage: UIImageView!
    @IBOutlet weak var secondImage: UIImageView!
    @IBOutlet weak var thirdImage: UIImageView!
    @IBOutlet weak var fourthImage: UIImageView!
    @IBOutlet weak var firstArrow: UIImageView!
    @IBOutlet weak var secondArrow: UIImageView!
    @IBOutlet weak var thirdArrow: UIImageView!
    @IBOutlet weak var fourthArrow: UIImageView!
    lazy var buttons: [UIButton] = [firstButton, secondButton, thirdButton, fourthButton]
    lazy var iconImage: [UIImageView] = [firstImage, secondImage, thirdImage, fourthImage]
    lazy var arrowImage: [UIImageView] = [firstArrow, secondArrow, thirdArrow, fourthArrow]

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            let json = try twoFactor?.getStatus()
            let methods = json!["methods"] as! NSArray
            for index in 0..<methods.count {
                let method = methods[index] as! String
                if(method == "email") {
                    buttons[index].setTitle("Email", for: UIControlState.normal)
                    iconImage[index].image = #imageLiteral(resourceName: "email")
                } else if (method == "sms") {
                    buttons[index].setTitle("SMS", for: UIControlState.normal)
                    iconImage[index].image = #imageLiteral(resourceName: "sms")
                } else if (method == "gauth") {
                    buttons[index].setTitle("Google Authenticator", for: UIControlState.normal)
                    iconImage[index].image = #imageLiteral(resourceName: "gauth")
                } else if (method == "phone") {
                    buttons[index].setTitle("Phone Call", for: UIControlState.normal)
                    iconImage[index].image = #imageLiteral(resourceName: "phoneCall")
                }
            }

            for index in methods.count..<buttons.count {
                buttons[index].isHidden = true
                iconImage[index].isHidden = true
                arrowImage[index].isHidden = true
            }
        } catch {
           print("couldn't get status")
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? VerifyTwoFactorViewController {
            let pair = sender as! (TwoFactorCall, String)
            let method = pair.1
            if(method == "sms") {
                nextController.topTitle = TitleText.sms
            } else if (method == "phone") {
                nextController.topTitle = TitleText.phone
            } else if (method == "email") {
                nextController.topTitle = TitleText.email
            } else if (method == "gauth") {
                nextController.topTitle = TitleText.gauth
            }
            nextController.twoFactor = pair.0
            nextController.hideButton = true
        }
    }

    @IBAction func buttonClicked(_ sender: Any) {
        let button = sender as! UIButton
        print("button " + String(button.tag) + " clicked")
        do {
        var method = ""
        if(button.title(for: .normal) == "Email") {
            try twoFactor?.requestCode(method: "email")
            method = "email"
        } else if (button.title(for: .normal) == "SMS") {
            try twoFactor?.requestCode(method: "sms")
            method = "sms"
        } else if (button.title(for: .normal) == "Google Authenticator") {
            try twoFactor?.requestCode(method: "gauth")
            method = "gauth"
        } else if (button.title(for: .normal) == "Phone Call") {
            try twoFactor?.requestCode(method: "phone")
            method = "phone"
        }
            let status = try twoFactor?.getStatus()
            let parsed = status!["status"] as! String
            if(parsed == "resolve_code") {
                self.performSegue(withIdentifier: "twoFactor", sender: (twoFactor, method))
            }
        } catch {
            print("couldn't get status")
        }

    }
}
