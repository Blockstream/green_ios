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

    override func viewDidLoad() {
        super.viewDidLoad()
        secret = AccountStore.shared.getGauthSecret()
        if (secret == nil) {
            print("something went wrong gauth")
            return
        }
        qrCodeImageView.image = QRImageGenerator.imageForText(text: secret!, frame: qrCodeImageView.frame)
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
                let status_call = json!["status"] as! String
                try factor?.call()
                let json_call1 = try factor?.getStatus()
                let status_call1 = json!["status"] as! String
                print(status_call)
                print("status call")
                self.performSegue(withIdentifier: "twoFactor", sender: factor)
            }
        } catch {
            print("something went wrong")
        }
    }

}
