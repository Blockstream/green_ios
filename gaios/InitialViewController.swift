//
//  InitialViewController.swift
//  GreenBitsIOS
//
//

import UIKit

class InitialViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        wrap {
            try getSession().connect(network: Network.TestNet, debug: true)
        }.done {
            print("Connected to TestNet")
        }.catch { error in
            print("Connection failed")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func unwindToInitialViewController(segue: UIStoryboardSegue) {
    }
}
