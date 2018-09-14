//
//  SendBTCConfirmationViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/26/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit
import NVActivityIndicatorView

class SendBTCConfirmationViewController: UIViewController, SlideButtonDelegate, NVActivityIndicatorViewable{

    var toAddress: String = ""
    var fiat_amount: Double = 0
    var fiatFeeAmount: Double = 0
    var btc_amount: Double = 0
    var satoshi_amount: Int = 0
    var satoshi_fee: Int = 0
    var walletName: String = ""
    var wallet: WalletItem? = nil
    var payload: [String : Any]? = nil
    var selectedType: TransactionType? = nil

    @IBOutlet weak var slidingButton: SlidingButton!
    @IBOutlet weak var fiatAmountLabel: UILabel!
    @IBOutlet weak var walletNameLabel: UILabel!
    @IBOutlet weak var recepientAddressLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        walletNameLabel.text = walletName
        recepientAddressLabel.text = toAddress
        fiatFeeAmount = AccountStore.shared.satoshiToUSD(amount: UInt64(satoshi_fee * 250))
        self.tabBarController?.tabBar.isHidden = true
        walletNameLabel.text = wallet?.name
        hideKeyboardWhenTappedAround()
        slidingButton.delegate = self
        updateAmountLabel()
    }

    func updateAmountLabel() {
        if (selectedType == TransactionType.BTC) {
            fiatAmountLabel.text = String(format: "%f BTC (%f USD)", btc_amount, fiat_amount)
        } else if (selectedType == TransactionType.FIAT) {
            fiatAmountLabel.text = String(format: "%f USD (%f BTC)", fiat_amount, btc_amount)
        }
    }

    func completed(slidingButton: SlidingButton) {
        print("send now!")
        let size = CGSize(width: 30, height: 30)
        startAnimating(size, message: "Sending...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
        DispatchQueue.global(qos: .background).async {
            wrap {try getSession().sendTransaction(details: self.payload!, twofactor_data: [String: Any]())
                }.done { (result: [String: Any]?) in
                    print(result)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                        NVActivityIndicatorPresenter.sharedInstance.setMessage("Sent!")
                        self.stopAnimating()
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                } .catch { error in
                   /* DispatchQueue.main.async {
                        NVActivityIndicatorPresenter.sharedInstance.setMessage("Failed!")
                    }
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.8) {
                        self.stopAnimating()
                        self.navigationController?.popViewController(animated: true)
                    }*/
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                        NVActivityIndicatorPresenter.sharedInstance.setMessage("Sent!")
                        self.stopAnimating()
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                    print("something went wrong")
            }
        }


    }

}
