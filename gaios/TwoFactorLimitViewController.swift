//
//  TwoFactorLimitViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 10/18/18.
//  Copyright © 2018 Blockstream.inc All rights reserved.
//

import Foundation
import UIKit

class TwoFactorLimitViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

}
