import Foundation
import UIKit
import PromiseKit

class TabViewController: UITabBarController {

    static let AUTOLOCK = "autolock"
    var startTime = DispatchTime.now()
    var endTime = DispatchTime.now()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(self.lockApplication(_:)), name: NSNotification.Name(rawValue: TabViewController.AUTOLOCK), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: Notification.Name.UIApplicationWillResignActive, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: TabViewController.AUTOLOCK), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIApplicationWillResignActive, object: nil)
    }

    @objc func lockApplication(_ notification: NSNotification) {
        let bgq = DispatchQueue.global(qos: .background)
        Guarantee().map(on: bgq){
            try! getSession().disconnect()
        }.done {
            getAppDelegate().lock()
        }
    }

    @objc func willEnterForeground(_ notification: NSNotification) {
        endTime = DispatchTime.now()
        let timeElapsed = (endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1000000000 //in seconds
        let settings = getGAService().getSettings()
        let timeout = settings != nil ? settings!.altimeout * 60 : 5*60
        if (timeElapsed < timeout) {
            return
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "autolock"), object: nil, userInfo:nil)
    }

    @objc func willResignActive(_ notification: NSNotification) {
        startTime = DispatchTime.now()
    }
}
