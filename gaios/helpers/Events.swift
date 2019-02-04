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
