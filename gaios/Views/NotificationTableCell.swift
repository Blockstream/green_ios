//
//  NotificationTableCell.swift
//  gaios
//
//  Created by Strahinja Markovic on 8/14/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
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
