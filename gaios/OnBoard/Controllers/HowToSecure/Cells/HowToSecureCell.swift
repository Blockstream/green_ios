//
//  HowToSecureCell.swift
//  gaios
//
//  Created by Mauro Olivo on 29/01/24.
//  Copyright © 2024 Blockstream Corporation. All rights reserved.
//

import UIKit

class HowToSecureCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblTxt: UILabel!
    @IBOutlet weak var hintView: UIView!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnDisclose: UIButton!
    @IBOutlet weak var icon: UIImageView!

    var model: HowToSecureCellModel?

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 5.0
        bg.borderWidth = 1.0
        bg.borderColor = .white.withAlphaComponent(0.1)
        btnDisclose.isUserInteractionEnabled = false
        btnDisclose.backgroundColor = UIColor.gAccent()
        btnDisclose.cornerRadius = 4.0
        lblTitle.setStyle(.subTitle)
        lblTxt.setStyle(.txtCard)
        lblTxt.textColor = UIColor.gW60()
        lblHint.font = UIFont.systemFont(ofSize: 12.0, weight: .semibold)
        hintView.cornerRadius = hintView.frame.size.height / 2.0
    }

    func configure(model: HowToSecureCellModel) {
        self.model = model
        lblTitle.text = model.title
        lblTxt.text = model.txt
        lblHint.text = model.hint
        icon.image = model.icon
    }
}
