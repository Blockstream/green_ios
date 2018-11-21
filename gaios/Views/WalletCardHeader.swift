//
//  WalletCardView.swift
//  gaios
//
//  Created by luca on 16/11/2018.
//  Copyright © 2018 Blockstream Corporation. All rights reserved.
//

import Foundation
import UIKit

class WalletCardHeader : CardView {
    var index: Int = 0
    var wallet: WalletItem? = nil

    @IBOutlet weak var qrImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var sendView: UIView!
    @IBOutlet weak var dividerView: UIView!
    @IBOutlet weak var receiveView: UIView!
}
