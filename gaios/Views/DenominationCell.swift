//
//  DenominationCell.swift
//  gaios
//
//  Created by Strahinja Markovic on 8/29/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class DenominationCell: UITableViewCell {

    var item: SettingsItem?
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
}
