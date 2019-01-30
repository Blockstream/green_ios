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

    static var restoreFromMnemonics = false

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
                        Toast.show(NSLocalizedString("id_new_transaction", comment: ""), timeout: Toast.SHORT_DURATION)
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
}
