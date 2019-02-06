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

struct Connection: Codable {
    enum CodingKeys: String, CodingKey {
        case connected = "connected"
        case loginRequired = "login_required"
        case heartbeatTimeout = "heartbeat_timeout"
        case elapsed = "elapsed"
        case waiting = "waiting"
        case limit = "limit"
    }
    let connected: Bool
    let loginRequired: Bool?
    let heartbeatTimeout: Bool?
    let elapsed: Int?
    let waiting: Int?
    let limit: Bool?
}

class GreenAddressService {

    private var session: Session? = nil
    private var settings: Settings? = nil
    private var twoFactorReset: TwoFactorReset? = nil
    private var events = Events([])

    static var restoreFromMnemonics = false

    public init() {
        session = try! Session(notificationCompletionHandler: newNotification)
    }

    func getSession() -> Session {
        return self.session!
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
        guard let dict = notification else {
            return
        }
        guard let notificationEvent: String = dict["event"] as? String else { return }
        guard let event: EventType = EventType.init(rawValue: notificationEvent) else { return }
        let data = dict[event.rawValue] as! [String: Any]
        switch event {
            case .Block:
                let blockHeight = data["block_height"] as! UInt32
                AccountStore.shared.setBlockHeight(height: blockHeight)
                post(event: .Block, data: data)
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
                print(data)
                let json = try! JSONSerialization.data(withJSONObject: data, options: [])
                let connection = try? JSONDecoder().decode(Connection.self, from: json)
                if let _ = connection {
                    if connection!.loginRequired == true {
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "autolock"), object: nil, userInfo:nil)
                    } else {
                        post(event: EventType.Network, data: data)
                    }
                }
                break
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
