import Foundation
import UIKit
import PromiseKit

class TabViewController: UITabBarController {

    private static let AUTOLOCK = "autolock"
    let snackbar = SnackBarNetwork()
    private var startTime = DispatchTime.now()
    private var endTime = DispatchTime.now()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(self.lockApplication(_:)), name: NSNotification.Name(rawValue: TabViewController.AUTOLOCK), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: Notification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateConnection), name: NSNotification.Name(rawValue: EventType.Network.rawValue), object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: TabViewController.AUTOLOCK), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Network.rawValue), object: nil)
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

    @objc func updateConnection(_ notification: NSNotification) {
        guard let connected = notification.userInfo?["connected"] as? Bool else { return }
        Guarantee().done {
            if connected {
                self.snackbar.connected(self.view)
            } else {
                guard let waiting = notification.userInfo?["waiting"] as? Int else { return }
                if waiting < 5 {
                    self.snackbar.removeFromSuperview()
                } else {
                    self.snackbar.disconnected(self.view, seconds: waiting)
                }
            }
        }
    }
}

class SnackBarNetwork: SnackBar {
    var timer = Timer()
    var seconds = 0

    func disconnected(_ superview: UIView, seconds: Int) {
        self.seconds = seconds
        label.text = String(format: NSLocalizedString("id_not_connected_connecting_in_ds_", comment: ""), seconds)
        button.setTitle(NSLocalizedString("id_try_now", comment: "").uppercased(), for: .normal)
        button.addTarget(self, action:#selector(self.click), for: .touchUpInside)
        button.isHidden = false
        if timer.isValid { timer.invalidate() }
        timer = Timer.scheduledTimer(timeInterval: 1.0,
                                                  target: self,
                                                  selector: #selector(self.update(_:)),
                                                  userInfo: nil,
                                                  repeats: true)
        addFromSuperview(superview)
    }

    func connected(_ superview: UIView) {
        label.text = NSLocalizedString("id_you_are_now_connected", comment: "")
        button.isHidden = true
        addFromSuperview(superview)
        if timer.isValid { timer.invalidate() }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(2000)) {
            self.removeFromSuperview()
        }
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        if timer.isValid { timer.invalidate() }
    }

    @objc private func update(_ timer: Timer) {
        Guarantee().done {
            if self.seconds > 0 {
                self.seconds -= 1
                self.label.text = String(format: NSLocalizedString("id_not_connected_connecting_in_ds_", comment: ""), self.seconds)
            }
        }
    }

    @objc func click(_ sender: UIButton) {
        let bgq = DispatchQueue.global(qos: .background)
        Guarantee().map(){
            self.removeFromSuperview()
        }.map(on: bgq){
            try getSession().reconnectHint(hint: ["hint": "now"])
        }.catch { _ in }
    }
}



