//
// ColoredCardView.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import UIKit

class ColoredCardView: CardView {

    @IBOutlet weak var QRImageView: UIImageView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    var index: Int = 0
    var wallet: WalletItem? = nil

    var presentedCardViewColor:          UIColor = UIColor.customTitaniumMedium()
    
    lazy var depresentedCardViewColor:   UIColor = UIColor.customTitaniumMedium()
    
    
     override func awakeFromNib() {
        
        contentView.layer.cornerRadius  = 10
        contentView.layer.masksToBounds = true
        
        presentedDidUpdate()
        
    }
    
    override var presented: Bool { didSet { presentedDidUpdate() } }
    
    func presentedDidUpdate() {
        contentView.backgroundColor = presented ? presentedCardViewColor : depresentedCardViewColor
        contentView.addTransitionFade()
        
    }

}
