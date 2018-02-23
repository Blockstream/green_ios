import Dispatch
import Foundation

import PromiseKit

import ga.sdk

public enum GaError: Error {
    case GenericError
    case ReconnectError
    case SessionLost
}

public enum Network: Int32 {
    case LocalTest = 0
    case RegTest = 1
    case TestNet = 2
}

fileprivate func errorWrapper(_ r: Int32) throws {
    guard r == GA_OK else {
        switch r {
            case GA_RECONNECT:
                throw GaError.ReconnectError
            case GA_SESSION_LOST:
                throw GaError.SessionLost
            default:
                throw GaError.GenericError
        }
    }
}

fileprivate func callWrapper(fun call: @autoclosure () -> Int32) throws {
    try errorWrapper(call())
}

fileprivate func convertOpaqueJsonToDict(fun call: (OpaquePointer, UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>) -> Int32, o: OpaquePointer) throws -> [String: Any]? {
    var bytes: UnsafeMutablePointer<Int8>? = nil
    try callWrapper(fun: call(o, &bytes))
    defer {
        GA_destroy_string(bytes)
    }

    var dict: [String: Any]? = nil

    let json = String(cString: bytes!)
    if let data = json.data(using: .utf8) {
        do {
            dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        }
        catch {
            return nil
        }
    }

    return dict
}

public class Transaction {
    public enum TransactionType {
        case Out
        case In
        case Redeposit
    }

    var tx: OpaquePointer? = nil;

    public init(tx: OpaquePointer) {
        self.tx = tx
    }

    deinit {
        GA_destroy_tx(tx)
    }

    public func toJSON() throws -> [String: Any]? {
        return try convertOpaqueJsonToDict(fun: GA_transaction_to_json, o: self.tx!)
    }
}

public class Session {
    var session: OpaquePointer? = nil

    public init() throws {
        try callWrapper(fun: GA_create_session(&session))
    }

    deinit {
        GA_destroy_session(session)
    }

    public func connect(network: Network, debug: Bool = false) throws {
        try callWrapper(fun: GA_connect(session, network.rawValue, debug ? GA_TRUE : GA_FALSE))
    }

    public func registerUser(mnemonic: String) throws {
        try callWrapper(fun: GA_register_user(session, mnemonic))
    }

    public func login(mnemonic: String) throws -> [String: Any]? {
        var login_data: OpaquePointer? = nil
        try callWrapper(fun: GA_login(session, mnemonic, &login_data))
        defer {
            GA_destroy_login_data(login_data)
        }
        return try convertOpaqueJsonToDict(fun: GA_convert_login_data_to_json, o: login_data!)
    }

    public func login(pin: String, pin_identifier_and_secret: String) throws -> [String: Any]? {
        var login_data: OpaquePointer? = nil
        try callWrapper(fun: GA_login_with_pin(session, pin, pin_identifier_and_secret, &login_data))
        defer {
            GA_destroy_login_data(login_data)
        }
        return try convertOpaqueJsonToDict(fun: GA_convert_login_data_to_json, o: login_data!)
    }

    public func login(username: String, password: String) throws -> [String: Any]? {
        var login_data: OpaquePointer? = nil
        try callWrapper(fun: GA_login_watch_only(session, username, password, &login_data))
        defer {
            GA_destroy_login_data(login_data)
        }
        return try convertOpaqueJsonToDict(fun: GA_convert_login_data_to_json, o: login_data!)
    }

    public func removeAccount() throws {
        try callWrapper(fun: GA_remove_account(session));
    }

    public func getTransactions(subaccount: Int) throws -> [Transaction]? {
        var txs: OpaquePointer? = nil
        try callWrapper(fun: GA_get_tx_list(session, 0, 0, subaccount, 0, 0, String(), &txs))
        defer {
            GA_destroy_tx_list(txs)
        }

        var count: Int = 0
        guard GA_tx_list_get_size(txs, &count) == GA_OK else {
            throw GaError.GenericError
        }

        var txss = [Transaction]()
        for i in 0..<count {
            var tx: OpaquePointer? = nil;
            guard GA_tx_list_get_tx(txs, i, &tx) == GA_OK else {
                throw GaError.GenericError
            }
            txss.append(Transaction(tx: tx!))
        }

        return txss
    }

    public func getReceiveAddress() throws -> String {
        var bytes: UnsafeMutablePointer<Int8>? = nil
        try callWrapper(fun: GA_get_receive_address(session, GA_ADDRESS_TYPE_P2SH, 0, &bytes))
        defer {
            GA_destroy_string(bytes)
        }
        return String(cString: bytes!)
    }

    public func getBalanceForSubaccount(subaccount: UInt32, numConfs: UInt32) throws -> [String: Any]? {
        var balance: OpaquePointer? = nil
        try callWrapper(fun: GA_get_balance_for_subaccount(session, Int(subaccount), Int(numConfs), &balance))
        defer {
            GA_destroy_balance(balance)
        }

        return try convertOpaqueJsonToDict(fun: GA_convert_balance_to_json, o: balance!)
    }

    public func getBalance(numConfs: UInt32) throws -> [String: Any]? {
        var balance: OpaquePointer? = nil
        try callWrapper(fun: GA_get_balance(session, Int(numConfs), &balance))
        defer {
            GA_destroy_balance(balance)
        }
        return try convertOpaqueJsonToDict(fun: GA_convert_balance_to_json, o: balance!)
    }

    public func getAvailableCurrencies() throws -> [String: Any]? {
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_get_available_currencies(session, &result))
        defer {
            GA_destroy_available_currencies(result)
        }
        return try convertOpaqueJsonToDict(fun: GA_convert_available_currencies_to_json, o: result!)
    }

    public func setPin(mnemonic: String, pin: String, device: String) throws -> String {
        var bytes: UnsafeMutablePointer<Int8>? = nil
        try callWrapper(fun: GA_set_pin(session, mnemonic, pin, device, &bytes))
        defer {
            GA_destroy_string(bytes)
        }
        return String(cString: bytes!)
    }

    func toCStr(strings: [String]) -> UnsafeMutablePointer<UnsafePointer<Int8>?> {
        let copies = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: strings.count)
        copies.initialize(to: nil, count: strings.count)
        let arr = strings.map { str -> UnsafePointer<Int8>? in
            var bytes: UnsafeMutablePointer<Int8>? = nil
            GA_copy_string(str, &bytes)
            return UnsafePointer<Int8>(bytes!)
        }
        for i in 0..<strings.count {
            copies.advanced(by: i).pointee = arr[i]
        }
        return copies
    }

    func clearCStr(copies: UnsafeMutablePointer<UnsafePointer<Int8>?>, count: Int) -> Void {
        for i in 0..<count {
            if let p = copies[i] {
                GA_destroy_string(p)
            }
        }
        copies.deinitialize(count: count)
        copies.deallocate(capacity: count)
    }

    public func send(addrAmt: [(String, UInt64)], feeRate: UInt64, sendAll: Bool = false) throws -> Void {
        let addresses = toCStr(strings: addrAmt.map { $0.0 })
        defer {
            clearCStr(copies: addresses, count: addrAmt.count)
        }
        try callWrapper(fun: GA_send(session, addresses, addrAmt.count, addrAmt.map { $0.1 }, addrAmt.count, feeRate, sendAll))
    }
}

public func generateMnemonic(lang: String) throws -> String {
    var bytes : UnsafeMutablePointer<Int8>? = nil
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

public func retry<T>(session: Session,
                     network: Network,
                     on: DispatchQueue = DispatchQueue.global(qos : .background),
                     mnemonic: String? = nil,
                     _ fun: @escaping () -> Promise<T>) -> Promise<T> {
    func retry_() -> Promise<T> {
        return fun().recover { error -> Promise<T> in
            guard error as! GaError == GaError.ReconnectError else { throw error }
            return after(interval: 2).then {
                return retry(session: session, network: network, on: on) { wrap { try session.connect(network: network, debug: true) } }
            }.then(on: on, execute: retry_)
        }
    }
    return retry_()
}

public func wrap<T>(_ fun: () throws -> T) -> Promise<T> {
    return Promise { fulfill, reject in
        do {
            fulfill(try fun())
        } catch GaError.ReconnectError {
            reject(GaError.ReconnectError)
        } catch {
            reject(GaError.GenericError)
        }
    }
}
