//
//  NotificationTableCell.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import UIKit

class NotificationTableCell: UITableViewCell {

    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var mainText: UILabel!
    


    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
}
