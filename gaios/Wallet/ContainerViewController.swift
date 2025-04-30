import Foundation
import UIKit
import core
import gdk

class ContainerViewController: UIViewController {

    private var networkToken: NSObjectProtocol?
    private var torToken: NSObjectProtocol?
    private var requests: Int = 0

    var walletModel: WalletModel?
    let nv = UINavigationController()

    @IBOutlet weak var networkView: UIView!
    @IBOutlet weak var networkText: UILabel!
    @IBOutlet weak var containerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()
        networkToken  = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: EventType.Network.rawValue), object: nil, queue: .main, using: updateConnection)
        self.networkView.isHidden = true
        view.accessibilityIdentifier = AccessibilityIdentifiers.ContainerScreen.view

        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let walletModel = walletModel {
            let vc = WalletTabBarViewController(walletModel: walletModel)
            nv.setViewControllers([vc], animated: false)
            nv.navigationBar.topItem?.title = ""
        }
        nv.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        nv.view.frame = containerView.bounds
        containerView.addSubview(nv.view)
        nv.willMove(toParent: self)
        nv.didMove(toParent: self)
        nv.beginAppearanceTransition(true, animated: true)
        nv.endAppearanceTransition()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let token = networkToken {
            NotificationCenter.default.removeObserver(token)
            networkToken = nil
        }
    }

    // network notification handler
    func updateConnection(_ notification: Notification) {
        let currentState = notification.userInfo?["current_state"] as? String
        let waitMs = notification.userInfo?["wait_ms"] as? Int
        let sessionId = notification.userInfo?["session_id"] as? String
        let connected = currentState == "connected"
        let tor = AppSettings.shared.gdkSettings?.tor ?? false
        if !isCurrentWallet(sessionId: sessionId ?? "") {
            return
        } else if connected {
            self.connected()
        } else if tor || waitMs ?? 0 > 3000 {
            self.offline()
        }
    }

    func isCurrentWallet(sessionId: String) -> Bool {
        WalletManager.current?
            .activeSessions
            .values
            .filter { $0.uuid.uuidString == sessionId }
            .first != nil
    }

    // show network bar on offline mode
    @objc private func offline() {
        DispatchQueue.main.async {
            self.networkView.backgroundColor = UIColor.errorRed()
            self.networkView.isHidden = false
            self.networkText.text = "id_connecting".localized
        }
    }

    // show network bar on connected mode
    func connected() {
        let sessions = WalletManager.current?.activeSessions ?? [:]
        let reconnected = sessions.filter { !$0.value.paused }
        if sessions.count != reconnected.count {
            return
        }
        DispatchQueue.main.async {
            if self.networkView.isHidden {
                return
            }
            self.networkText.text = "id_you_are_now_connected".localized
            self.networkView.backgroundColor = UIColor.gAccent()
            self.networkView.isHidden = false
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(2000)) {
                self.networkView.isHidden = true
            }
        }
    }
}
