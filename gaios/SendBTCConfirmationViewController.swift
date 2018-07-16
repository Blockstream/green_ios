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
    
    var toAddress: String = ""
    var fiat_amount: Double = 0
    var fiatFeeAmount: Double = 0
    var btc_amount: Double = 0
    var satoshi_amount: Int = 0
    var satoshi_fee: Int = 0
    var walletName: String = ""
    var wallet: WalletItem? = nil

    @IBOutlet weak var fiatAmountLabel: UILabel!
    @IBOutlet weak var walletNameLabel: UILabel!
    @IBOutlet weak var recepientAddressLabel: UILabel!
    @IBOutlet weak var totalLabel: UILabel!
    @IBOutlet weak var feelabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        fiatAmountLabel.text = String(format: "%.2f USD (%.4f BTC)", fiat_amount, btc_amount)
        walletNameLabel.text = walletName
        recepientAddressLabel.text = toAddress
        fiatFeeAmount = AccountStore.shared.satoshiToUSD(amount: satoshi_fee * 250)
        totalLabel.text = String(format: "%.2f USD", fiat_amount+fiatFeeAmount)
        self.tabBarController?.tabBar.isHidden = true
        walletNameLabel.text = wallet?.name
        feelabel.text = String(format: "(incl. %.2f USD fee)", fiatFeeAmount)
    }

    @IBAction func sendButtonClicked(_ sender: Any) {
        wrap { return try getSession().send(addrAmt: [(self.toAddress, 100)], feeRate: 1000) }
            .done { () in
                self.navigationController?.popToRootViewController(animated: true)
            }.catch { error in
                print("sending failed ", error)
        }
    }
}
