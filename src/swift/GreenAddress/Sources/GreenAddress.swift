import Foundation

import ga.sdk

public enum GaError: Error {
    case GenericError
}

public enum Network: Int32 {
    case LocalTest = 0
    case RegTest = 1
    case TestNet = 2
}

public struct Transaction {
    public enum TransactionType {
        case Out
        case In
        case Recovery
    }

    let amount: Int64
    let type: TransactionType
    let tx: [String: Any]

    public init(tx: [String: Any]) {
        self.tx = tx;

        var amount: Int64 = 0

        let epsList : [[String: Any]] = tx["eps"] as! [[String: Any]]
        for eps in epsList {
            let isCredit = eps["is_credit"] as! Bool
            let isRelevant = eps["is_relevant"] as! Bool

            if (!isRelevant) {
                continue;
            }

            if let value_str = eps["value"] {

                let value = Int64(value_str as! String)

                if (!isCredit) {
                    amount -= value!
                }
                else {
                    amount += value!
                }
            }
        }

        if amount >= 0 {
            self.type = TransactionType.In
        }
        else {
            self.type = TransactionType.Out
        }

        self.amount = amount
    }

    func getAs<T>(key: String) -> T {
        return tx[key] as! T
    }

    public func getFee() -> Int64 {
        return getAs(key: "fee")
    }

    public func isInstant() -> Bool {
        return getAs(key: "instant")
    }

    public func getType() -> TransactionType {
        return self.type
    }

    public func getAmount() -> Int64 {
        return self.amount
    }
}

public class Session {
    var session: OpaquePointer? = nil

    public init() throws {
        guard GA_create_session(&session) == GA_OK else {
            throw GaError.GenericError
        }
    }

    deinit {
        GA_destroy_session(session)
    }

    public func connect(network: Network, debug: Bool = false) throws {
        guard GA_connect(session, network.rawValue, debug ? GA_TRUE : GA_FALSE) == GA_OK else {
            throw GaError.GenericError
        }
    }

    public func registerUser(mnemonic: String) throws {
        guard GA_register_user(session, mnemonic) == GA_OK else {
            throw GaError.GenericError
        }
    }

    public func login(mnemonic: String) throws {
        guard GA_login(session, mnemonic) == GA_OK else {
            throw GaError.GenericError
        }
    }

    func transactionsFromDict(txList: [[String: Any]]) -> [Transaction] {
        var txs = [Transaction]()
        for tx in txList {
            txs.append(Transaction(tx: tx))
        }
        return txs
    }

    public func getTxList(begin: Date, end: Date, subaccount: Int) throws -> [Transaction]? {
        var txs: OpaquePointer? = nil
        let startDate = Int(begin.timeIntervalSince1970)
        let endDate = Int(end.timeIntervalSince1970)
        guard GA_get_tx_list(session, startDate, endDate, subaccount, 0, 0, String(), &txs) == GA_OK else {
            throw GaError.GenericError
        }
        defer {
            GA_destroy_tx_list(txs)
        }

        var bytes : UnsafeMutablePointer<Int8>? = nil
        guard GA_convert_tx_list_to_json(txs, &bytes) == GA_OK else {
            throw GaError.GenericError
        }
        defer {
            GA_destroy_string(bytes)
        }

        var dict: [String: Any]? = nil

        let json: String = String(cString: bytes!)
        if let data = json.data(using: .utf8) {
            do {
                dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                return nil
            }
        }

        if let list = dict?["list"] {
            return transactionsFromDict(txList: list as! [[String: Any]])
        }
        else {
            return nil;
        }
    }

    public func getReceiveAddress() -> String? {
        var bytes : UnsafeMutablePointer<Int8>? = nil
        guard GA_get_receive_address(session, GA_ADDRESS_TYPE_P2SH, 0, &bytes) == GA_OK else {
            return nil 
        }
        defer {
            GA_destroy_string(bytes)
        }
        return String(cString: bytes!)
    }
}

public func generateMnemonic(lang: String) throws -> String {
    var bytes : UnsafeMutablePointer<Int8>?
    guard GA_generate_mnemonic(lang, &bytes) == GA_OK else {
        throw GaError.GenericError
    }
    defer {
        GA_destroy_string(bytes)
    }

    return String(cString: bytes!)
}

public func validateMnemonic(lang: String, mnemonic: String) -> Bool {
    return GA_validate_mnemonic(lang, mnemonic) == GA_TRUE
}
