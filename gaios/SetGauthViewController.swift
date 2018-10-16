//
//  SetGauthViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import UIKit

class SetGauthViewController: UIViewController {

    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var secretLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    var secret: String? = ""
    var otp: String? = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        secret = AccountStore.shared.getGauthSecret()
        otp = AccountStore.shared.getGauthOTP()
        if (secret == nil) {
            print("something went wrong gauth")
            return
        }
        qrCodeImageView.image = QRImageGenerator.imageForText(text: otp!, frame: qrCodeImageView.frame)
        secretLabel.text = secret
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func nextButtonClicked(_ sender: Any) {
        let factor = AccountStore.shared.enableGauthTwoFactor()
        do {
            let json = try factor?.getStatus()
            let status = json!["status"] as! String
            if (status == "call") {
                try factor?.call()
                let json_call = try factor?.getStatus()
                let status_call = json_call!["status"] as! String
                if(status_call == "resolve_code") {
                    self.performSegue(withIdentifier: "twoFactor", sender: factor)
                }
            }
        } catch {
            print("something went wrong")
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? VerifyTwoFactorViewController {
            nextController.onboarding = true
            nextController.twoFactor = sender as! TwoFactorCall
        }
    }
}
