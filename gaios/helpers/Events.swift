import Foundation

struct TransactionEvent: Codable {
    enum CodingKeys: String, CodingKey {
        case txHash = "txhash"
        case type = "type"
        case subAccounts = "subaccounts"
        case satoshi = "satoshi"
    }
    let txHash: String
    let type: String
    let subAccounts: [Int]
    let satoshi: UInt64
}

struct Event: Equatable {
    enum CodingKeys: String, CodingKey {
        case type
        case value
    }
    var type: EventType
    var value: [String: Any]

    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.type == rhs.type && NSDictionary(dictionary: lhs.value).isEqual(to: rhs.value)
    }


    func get<T>() -> T? {
        switch type {
        case .Transaction:
            return try? JSONDecoder().decode(TransactionEvent.self, from: JSONSerialization.data(withJSONObject: value, options: [])) as! T
        case .TwoFactorReset:
            return try? JSONDecoder().decode(TwoFactorReset.self, from: JSONSerialization.data(withJSONObject: value, options: [])) as! T
        case .Settings:
            return try? JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: value, options: [])) as! T
        default:
            return nil
        }
    }

    func title() -> String {
        switch type {
        case .Transaction:
            guard let transaction = get() as TransactionEvent? else { return "" }
            return NSLocalizedString("id_new_transaction", comment: "")
        case .TwoFactorReset, .Settings:
            guard let twoFactorReset = getGAService().getTwoFactorReset() else { return "" }
            if twoFactorReset.isResetActive {
                return NSLocalizedString("id_twofactor_reset_in_progress", comment: "")
            }
            guard let dataTwoFactorConfig = try? getSession().getTwoFactorConfig() else { return "" }
            guard let twoFactorConfig = try? JSONDecoder().decode(TwoFactorConfig.self, from: JSONSerialization.data(withJSONObject: dataTwoFactorConfig!, options: [])) else { return "" }
            if !twoFactorConfig.anyEnabled {
                return NSLocalizedString("id_set_up_twofactor_authentication", comment: "")
            } else if twoFactorConfig.enableMethods.count == 1 {
                return NSLocalizedString("id_set_up_twofactor_authentication", comment: "")
            }
            return ""
        default:
            return ""
        }
    }

    func description() -> String {
        guard let settings = getGAService().getSettings() else { return "" }
        switch type {
        case .Transaction:
            guard let txEvent = get() as TransactionEvent? else { return "" }
            let txType = txEvent.type == "incoming" ? NSLocalizedString("id_incoming", comment: "") : NSLocalizedString("id_outgoing", comment: "")
            let txAmount = String.formatBtc(satoshi: txEvent.satoshi, value: nil, fromType: nil, toType: settings.denomination)
            let wallets = AccountStore.shared.wallets.filter { txEvent.subAccounts.contains(Int($0.pointer)) }
            let txWalletName = wallets.isEmpty ? "" : wallets[0].localizedName()
            return String(format: NSLocalizedString("id_new_s_transaction_of_s_in", comment: ""), txType, txAmount, txWalletName)
        case .TwoFactorReset, .Settings:
            guard let twoFactorReset = getGAService().getTwoFactorReset() else { return "" }
            if twoFactorReset.isResetActive {
                return NSLocalizedString("id_twofactor_reset_in_progress", comment: "")
            }
            guard let dataTwoFactorConfig = try? getSession().getTwoFactorConfig() else { return "" }
            guard let twoFactorConfig = try? JSONDecoder().decode(TwoFactorConfig.self, from: JSONSerialization.data(withJSONObject: dataTwoFactorConfig!, options: [])) else { return "" }
            if !twoFactorConfig.anyEnabled {
                return NSLocalizedString("id_your_wallet_is_not_yet_fully", comment: "")
            } else if twoFactorConfig.enableMethods.count == 1 {
                return NSLocalizedString("id_you_only_have_one_twofactor", comment: "")
            }
            return ""
        default:
            return ""
        }
    }
}

struct Events : MutableCollection {
    private var events: [Event] = []
    init(_ events: [Event]) { self.events = events }
    var startIndex : Int { return 0 }
    var endIndex : Int { return events.count }
    func index(after i: Int) -> Int { return i + 1 }
    subscript(position : Int) -> Event {
        get { return events[position] }
        set(newEvent) { events[position] = newEvent }
    }
    mutating func append(_ newEvent: Event) {
        if events.contains(newEvent) {
            guard let pos = events.firstIndex(of: newEvent) else { return }
            events[pos] = newEvent
        } else {
            events.append(newEvent)
        }
    }
}
