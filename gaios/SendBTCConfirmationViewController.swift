//
//  SendBTCConfirmationViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/26/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class SendBTCConfirmationViewController: UIViewController {
    
    var toAddress: String? = nil
    var fee: Int = 0
    var amount: Double = 0
    
    @IBOutlet weak var fiatAmountLabel: UILabel!
    @IBOutlet weak var btcAmountLabel: UILabel!
    
    @IBOutlet weak var toAddressLabel: UILabel!
    @IBOutlet weak var feeLabel: UILabel!
    @IBOutlet weak var totalAmountLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        btcAmountLabel.text = String(format: "%.5f BTC", amount)
        toAddressLabel.text = toAddress
        
        self.tabBarController?.tabBar.isHidden = true
    }

}
