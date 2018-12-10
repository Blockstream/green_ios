import Foundation
import UIKit

class CustomApplication: UIApplication {

    private var timeoutInSeconds: TimeInterval {
        guard let settings = getGAService().getSettings() else { return 5 * 60 }
        let time = TimeInterval(settings.altimeout * 60)
        return time
    }

    private var idleTimer: Timer?

    private func resetIdleTimer() {
        if let idleTimer = idleTimer {
            idleTimer.invalidate()
        }
        idleTimer = Timer.scheduledTimer(timeInterval: timeoutInSeconds,
                                         target: self,
                                         selector: #selector(CustomApplication.timeout),
                                         userInfo: nil,
                                         repeats: false
        )
    }

    @objc private func timeout() {
        print("lock me")
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "autolock"), object: nil, userInfo:nil)
    }

    override func sendEvent(_ event: UIEvent) {

        super.sendEvent(event)

        if idleTimer != nil {
            self.resetIdleTimer()
        }

        if let touches = event.allTouches {
            for touch in touches where touch.phase == UITouchPhase.began {
                self.resetIdleTimer()
            }
        }
    }
}
