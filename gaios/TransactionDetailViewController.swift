//
//  TransactionDetailViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 10/9/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class TransactionDetailViewController: UIViewController {


    @IBOutlet weak var hashLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var feeLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var warniniglabel: UILabel!

    var transaction: TransactionItem? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        hashLabel.text = transaction?.hash
        amountLabel.text = transaction?.amount
        feeLabel.text = feeText(fee: (transaction?.fee)!, size: (transaction?.size)!)
        memoLabel.text = transaction?.memo
        dateLabel.text = transaction?.date
        warniniglabel.isHidden = true
        //something
    }

    func feeText(fee: UInt32, size: UInt32) -> String {
        let perbyte = Double(fee/size)
        return String(format: "Transaction fee is %d satoshi, %.2f satoshi per byte", fee, perbyte)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
}
