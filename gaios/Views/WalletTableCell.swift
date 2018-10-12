//
//  WalletTableCell.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import UIKit

class WalletTableCell: UITableViewCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        // Initialization code
    }
    
    @IBOutlet var balance: UILabel!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var mainContent: UIView!
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
