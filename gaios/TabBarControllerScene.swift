//
//  TabBarControllerScene.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import UIKit

class TabBarControllerScene: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.setHidesBackButton(true, animated: false)

        self.selectedIndex = 1
    }
}
