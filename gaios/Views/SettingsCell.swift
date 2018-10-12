//
//  SettingsCell.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import UIKit

class SettingsCell: UITableViewCell {


    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var rightLabel: UILabel!
    var item: SettingsItem?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
}
