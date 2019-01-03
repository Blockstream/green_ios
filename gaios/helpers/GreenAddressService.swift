import Foundation
import UIKit
import PromiseKit

enum EventType: String {
    case Block = "block"
    case Transaction = "transaction"
    case TwoFactorReset = "twofactor_reset"
    case Settings = "settings"
    case AddressChanged = "address_changed"
    case Network = "network"
}

class GreenAddressService: SessionNotificationDelegate {

    private var session: Session = try! Session()
    private var settings: Settings?
    private var twoFactorReset: TwoFactorReset?
    private var events = Events([])

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

    func getEvents() -> Events {
        return events
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
                post(event: .Block, data: data)
                break
            case .Transaction:
                let json = try! JSONSerialization.data(withJSONObject: data, options: [])
                let txEvent = try! JSONDecoder().decode(TransactionEvent.self, from: json)
                events.append(Event(type: .Transaction, value: data))
                post(event: .Transaction, data: data)

                // TODO refactoring notifications
                if txEvent.type == "incoming" {
                    updateAddresses(txEvent.subAccounts.map{ UInt32($0)})
                    DispatchQueue.main.async {
                        self.showIncomingNotification()
                    }
                }
                break
            case .TwoFactorReset:
                let json = try! JSONSerialization.data(withJSONObject: data, options: [])
                self.twoFactorReset = try! JSONDecoder().decode(TwoFactorReset.self, from: json)
                events.append(Event(type: .TwoFactorReset, value: data))
                post(event: .TwoFactorReset, data: data)
            case .Settings:
                let json = try! JSONSerialization.data(withJSONObject: data, options: [])
                self.settings = try! JSONDecoder().decode(Settings.self, from: json)
                post(event: .Settings, data: data)
            case .Network:
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "autolock"), object: nil, userInfo:nil)
            default:
                break
        }
    }

    func post(event: EventType, data: [String: Any]) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: event.rawValue), object: nil, userInfo: data)
    }

    func updateAddresses(_ accounts: [UInt32]) {
        changeAddresses(accounts).done { (wallets: [WalletItem]) in
            wallets.forEach { wallet in
                guard let address = wallet.receiveAddress else { return }
                self.post(event: .AddressChanged, data: ["pointer": wallet.pointer, "address": address])
            }
        }.catch { _ in }
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
        label.text = NSLocalizedString("id_new_transaction", comment: "")
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
