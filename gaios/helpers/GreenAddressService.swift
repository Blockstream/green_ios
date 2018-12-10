import Foundation
import UIKit
import PromiseKit

class GreenAddressService: SessionNotificationDelegate {

    private var session: Session = try! Session()
    private var settings: Settings?
    private var twoFactorReset: TwoFactorReset?

    public init() {
        Session.delegate = self
    }

    func getSession() -> Session {
        return self.session
    }

    func getSettings() -> Settings? {
        return settings
    }

    func getTwoFactorReset() -> TwoFactorReset? {
        return twoFactorReset
    }

    enum EventType: String {
        case Block = "block"
        case Transaction = "transaction"
        case TwofactorReset = "twofactor_reset"
        case Settings = "settings"
    }

    func newNotification(notification: [String : Any]?) {
        guard let dict: [String : Any] = notification else { return }
        guard let notificationEvent: String = dict["event"] as? String else { return }
        guard let event: EventType = EventType.init(rawValue: notificationEvent) else { return }
        let data = dict[event.rawValue] as! [String: Any]
        switch event {
            case .Block:
                let blockHeight = data["block_height"] as! UInt32
                AccountStore.shared.setBlockHeight(height: blockHeight)
                break
            case .Transaction:
                let type = data["type"] as! String
                let hash = data["txhash"] as! String
                var subaccounts = Array<Int>()
                if let accounts = data["subaccounts"] as? [Int] {
                    subaccounts.append(contentsOf: accounts)
                }
                if let account = data["subaccounts"] as? Int {
                    subaccounts.append(account)
                }
                // TODO refactoring notifications
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "transaction"), object: nil, userInfo: ["subaccounts" : subaccounts])
                if (type == "incoming") {
                    print("incoming transaction")
                    DispatchQueue.main.async {
                        self.showIncomingNotification()
                    }
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "incomingTX"), object: nil, userInfo: ["subaccounts" : subaccounts])
                } else if (type == "outgoing"){
                    print("outgoing transaction")
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "outgoingTX"), object: nil, userInfo: ["subaccounts" : subaccounts, "txhash" : hash])
                }
                break
            case .TwofactorReset:
                let json = try! JSONSerialization.data(withJSONObject: data, options: [])
                self.twoFactorReset = try! JSONDecoder().decode(TwoFactorReset.self, from: json)
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "twoFactorReset"), object: nil, userInfo: ["twoFactorReset" : dict])
            case .Settings:
                let json = try! JSONSerialization.data(withJSONObject: data, options: [])
                self.settings = try! JSONDecoder().decode(Settings.self, from: json)
        }
    }

    // TODO: remove from here
    func showIncomingNotification() {
        let window = UIApplication.shared.keyWindow!
        let v = UIView(frame: window.bounds)
        window.addSubview(v);
        v.backgroundColor = UIColor.black
        let label = UILabel()
        label.frame = CGRect(x: 0, y: 0, width: 120, height: 30)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Transaction Received"
        label.textColor = UIColor.white
        label.textAlignment = .center
        v.addSubview(label)
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 220).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 30).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: v, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: v, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0).isActive = true
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.3) {
            v.removeFromSuperview()
        }
    }
}
