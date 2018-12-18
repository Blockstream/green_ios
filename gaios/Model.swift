
import Foundation
import PromiseKit

struct Transactions {
    let list: [Transaction]
    let nextPageId: UInt32
    let pageId: UInt32

    init(list: [Transaction], nextPageId: UInt32, pageId: UInt32) {
        self.list = list
        self.nextPageId = nextPageId
        self.pageId = pageId
    }
}

enum TransactionError : Error {
    case invalid(localizedDescription: String)
}

struct Addressee : Codable {
    let address: String
    let satoshi: UInt64

    init(address: String, satoshi: UInt64) {
        self.address = address
        self.satoshi = satoshi
    }
}

struct Transaction {
    var details: [String: Any]

    private func get<T>(_ key: String) -> T? {
        return details[key] as? T
    }

    init(_ details: [String: Any]) {
        self.details = details
    }

    var addressees: [Addressee] {
        get {
            let o: [[String: Any]] = get("addressees") ?? []
            return o.map { value in
                return Addressee(address: value["address"] as! String, satoshi: (value["satoshi"] as? UInt64) ?? 0)
            }
        }
        set {
            let addressees = newValue.map { addr -> [String: Any] in
                var o = [String: Any]()
                o["address"] = addr.address
                o["satoshi"] = addr.satoshi
                return o
            }
            details["addressees"] = addressees
        }
    }

    var addresseesReadOnly: Bool {
        get { return get("addresses_read_only") ?? false }
    }

    var blockHeight: UInt32 {
        get { return get("block_height") ?? 0 }
    }

    var canRBF: Bool {
        get { return get("can_rbf") ?? false }
    }

    var createdAt: String {
        get { return get("created_at") ?? String() }
    }

    var error: String {
        get { return get("error") ?? String() }
    }

    var fee: UInt64 {
        get { return get("fee") ?? 0 }
    }

    var feeRate: UInt64 {
        get { return get("fee_rate" ) ?? 0 }
        set { details["fee_rate"] = newValue }
    }

    var hash: String {
        get { return get("txhash") ?? String() }
    }

    var isSweep: Bool {
        get { return get("is_sweep") ?? false }
    }

    var memo: String {
        get { return get("memo") ?? String() }
        set { details["memo"] = newValue }
    }

    var satoshi: UInt64 {
        get { return get("satoshi") ?? 0 }
    }

    var sendAll: Bool {
        get { return get("send_all") ?? false }
        set { details["send_all"] = newValue }
    }

    var size: UInt64 {
        get { return get("transaction_vsize") ?? 0 }
    }

    var type: String {
        get { return get("type") ?? String() }
    }

    func amount() -> String {
        let satoshi = String.formatBtc(satoshi: self.satoshi)
        if type == "outgoing" || type == "redeposit" {
            return "-" + satoshi
        } else {
            return satoshi
        }
    }

    func address() -> String? {
        let o: [String] = get("addressees") ?? []
        guard !o.isEmpty else {
            return nil
        }
        return o[0]
    }

    func date() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let date = Date.dateFromString(dateString: createdAt)
        return Date.dayMonthYear(date: date)
    }

}

class WalletItem : Codable {

    enum CodingKeys: String, CodingKey {
        case bits
        case btc
        case fiat
        case fiatCurrency = "fiat_currency"
        case fiatRate = "fiat_rate"
        case mbtc
        case name
        case pointer
        case receiveAddress
        case receivingId = "receiving_id"
        case satoshi
        case type
        case ubtc
    }

    let bits: String
    let btc: String
    let fiat: String
    let fiatCurrency: String
    let fiatRate: String
    let mbtc: String
    private let name: String
    let pointer: UInt32
    var receiveAddress: String?
    let receivingId: String
    var satoshi: UInt64
    let type: String
    let ubtc: String

    func localizedName() -> String {
        return pointer == 0 ? NSLocalizedString("id_main", comment: "") : name
    }

    func generateNewAddress() -> String? {
        return try? getSession().getReceiveAddress(subaccount: self.pointer)
    }

    func getAddress() -> String {
        if let address = receiveAddress {
            return address
        }
        receiveAddress = generateNewAddress()
        return receiveAddress ?? String()
    }

    func getBalance() -> Promise<UInt64> {
        let bgq = DispatchQueue.global(qos: .background)
        return Guarantee().compactMap(on: bgq) {
            try getSession().getBalance(subaccount: self.pointer, numConfs: 0)
        }.compactMap(on: bgq) { balance in
            return balance["satoshi"] as? UInt64
        }.compactMap { satoshi in
            self.satoshi = satoshi
            return satoshi
        }
    }
}

class Wallets : Codable {
    let array: [WalletItem]
}

func getTransactionDetails(txhash: String) -> Promise<[String: Any]> {
    let bgq = DispatchQueue.global(qos: .background)
    return Guarantee().compactMap(on: bgq) {
        try getSession().getTransactionDetails(txhash: txhash)
    }
}

func createTransaction(details: [String: Any]) -> Promise<Transaction> {
    let bgq = DispatchQueue.global(qos: .background)
    return Guarantee().compactMap(on: bgq) {
        try getSession().createTransaction(details: details)
    }.map(on: bgq) { data in
        return Transaction(data)
    }
}

func signTransaction(details: [String: Any]) -> Promise<TwoFactorCall> {
    let bgq = DispatchQueue.global(qos: .background)
    return Guarantee().compactMap(on: bgq) {
        try getSession().signTransaction(details: details)
    }
}

func createTransaction(transaction: Transaction) -> Promise<Transaction> {
    return createTransaction(details: transaction.details)
}

func signTransaction(transaction: Transaction) -> Promise<TwoFactorCall> {
    return signTransaction(details: transaction.details)
}

func convertAmount(details: [String: Any]) -> [String: Any]? {
    guard let conversion = try? getSession().convertAmount(input: details) else {
        return nil
    }
    return conversion
}

func getFeeEstimates() -> [UInt64] {
    let estimates = try! getSession().getFeeEstimates()
    return estimates!["fees"] as! [UInt64]
}

func getUserNetworkSettings() -> [String: Any]? {
    return UserDefaults.standard.value(forKey: "network_settings") as? [String: Any]
}
