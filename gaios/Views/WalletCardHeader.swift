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
    @IBOutlet weak var qrImageView: UIImageView!

    @IBOutlet weak var nameLabel: UILabel!

    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    var index: Int = 0
    var wallet: WalletItem? = nil

    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var receiveButton: UIButton!
    
}
