//
//  NoInternetViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import  UIKit

class NoInternetViewController: UIViewController {

    @IBOutlet weak var bottomButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func refreshClicked(_ sender: Any) {
        print("recconect or do whatever needs to be done")
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bottomButton.layoutIfNeeded()
        bottomButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }
}
