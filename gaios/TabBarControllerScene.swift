//
//  TabBarControllerScene.swift
//  GreenBitsIOS
//

import UIKit

class TabBarControllerScene: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.setHidesBackButton(true, animated: false)
    }
}
