//
//  TabBarController.swift
//  green_ios_navigation_test
//
//  Created by luca on 15/11/2018.
//  Copyright © 2018 luca. All rights reserved.
//

import Foundation
import UIKit

class TabBarController : UITabBarController {

    var leftSwipe: UISwipeGestureRecognizer?
    var rightSwipe: UISwipeGestureRecognizer?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipes(_:)))
        rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipes(_:)))
        leftSwipe!.direction = .left
        rightSwipe!.direction = .right
        self.view.addGestureRecognizer(leftSwipe!)
        self.view.addGestureRecognizer(rightSwipe!)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.view.removeGestureRecognizer(leftSwipe!)
        self.view.removeGestureRecognizer(rightSwipe!)
    }


    @objc func handleSwipes(_ sender: UISwipeGestureRecognizer) {
        if sender.direction == .left {
            self.selectedIndex += 1
        }
        if sender.direction == .right {
            self.selectedIndex -= 1
        }
    }
}
