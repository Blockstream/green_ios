import Dispatch
import Foundation

import PromiseKit

import ga.sdk

public enum GaError: Error {
    case GenericError
    case ReconnectError
    case SessionLost
    case TimeoutError
}

public enum Network: UInt32 {
    case MainNet = 0
    case TestNet = 1
    case LocalTest = 100
    case RegTest = 101
}

fileprivate func errorWrapper(_ r: Int32) throws {
    guard r == GA_OK else {
        switch r {
            case GA_RECONNECT:
                throw GaError.ReconnectError
            case GA_SESSION_LOST:
                throw GaError.SessionLost
            case GA_TIMEOUT:
                throw GaError.TimeoutError
            default:
                throw GaError.GenericError
        }
    }
}

fileprivate func callWrapper(fun call: @autoclosure () -> Int32) throws {
    try errorWrapper(call())
}

fileprivate func convertJSONBytesToDict(_ input_bytes: UnsafeMutablePointer<Int8>) -> [String: Any]? {
    var dict: Any?
    let json = String(cString: input_bytes)
    if let data = json.data(using: .utf8) {
        do {
            dict = try JSONSerialization.jsonObject(with: data, options: [])
            if let object = dict as? [String: Any] {
                // json is a dictionary
                return object
            } else if let object = dict as? [Any] {
                // json is an array
                return ["array" : object]
            }
        }
        catch {
            return nil
        }
    }
    return dict as? [String: Any]
}

fileprivate func convertDictToJSON(dict: [String: Any]) throws -> OpaquePointer {
    let utf8_bytes = try JSONSerialization.data(withJSONObject: dict)
    var result: OpaquePointer? = nil
    let input = String(data: utf8_bytes, encoding: String.Encoding.utf8)!
    try callWrapper(fun: GA_convert_string_to_json(input, &result))
    return result!
}

fileprivate func convertOpaqueJsonToDict(o: OpaquePointer) throws -> [String: Any]? {
    var buff: UnsafeMutablePointer<Int8>? = nil
    try callWrapper(fun: GA_convert_json_to_string(o, &buff))
    defer {
        GA_destroy_string(buff)
    }
    return convertJSONBytesToDict(buff!)
}

fileprivate func convertOpaqueJsonToString(o: OpaquePointer) throws -> String? {
    var buff: UnsafeMutablePointer<Int8>? = nil
    defer {
        GA_destroy_string(buff)
    }
    try callWrapper(fun: GA_convert_json_to_string(o, &buff))
    return String(cString: buff!)
}

// An authentication factor for 2fa, e.g. email, sms, phone, gauth
public class AuthenticationFactor {
    private var optr: OpaquePointer? = nil

    public init(optr: OpaquePointer) {
        self.optr = optr
    }

    public func requestCode(op: OpaquePointer) throws {
        try callWrapper(fun: GA_twofactor_request_code(self.optr!, op))
    }
}

// An operation that potentially requires two factor authentication and multiple
// iterations to complete, e.g. twofactor.set_email/activate_email
public class TwoFactorCall {
    private var optr: OpaquePointer? = nil
    private var parent: TwoFactorCall? = nil

    public init(optr: OpaquePointer) {
        self.optr = optr
    }

    public init(optr: OpaquePointer, parent: TwoFactorCall) {
        self.optr = optr
        self.parent = parent
    }

    deinit {
        if (parent == nil) {
            GA_destroy_twofactor_call(optr);
        }
    }

    // Return the list of authentication factors applicable to the operation
    // If the list is empty, call call() directly
    // If there are multiple items, ask the user to select one
    // Once the user has selected a factor, or if there is only one factor, call
    // requestCode, resolveCode and then call
    public func getAuthenticationFactors() throws -> [AuthenticationFactor] {
        var methods: OpaquePointer? = nil
        try callWrapper(fun: GA_twofactor_get_factors(self.optr, &methods))

        var count: UInt32 = 0
        try callWrapper(fun: GA_twofactor_factor_list_get_size(methods, &count))

        var factors: [AuthenticationFactor] = []
        for i in 0..<count {
            var method: OpaquePointer? = nil
            try callWrapper(fun: GA_twofactor_factor_list_get_factor(methods, i, &method))
            factors.append(AuthenticationFactor(optr: method!))
        }
        return factors
    }

    // Request that the backend sends a 2fa code
    public func requestCode(factor: AuthenticationFactor?) throws -> Promise<AuthenticationFactor?> {
        if (factor != nil) {
            try factor!.requestCode(op: self.optr!)
        }
        return Promise<AuthenticationFactor?> { seal in seal.fulfill(factor) }
    }

    // Provide the 2fa code sent by the server
    public func resolveCode(code: String?) throws -> Promise<Void> {
        if (code != nil) {
            try callWrapper(fun: GA_twofactor_resolve_code(self.optr, code))
        }
        return Promise<Void> { seal in seal.fulfill(()) }
    }

    // Call the 2fa operation
    // Returns the next 2fa operation in the chain
    public func call() throws -> Promise<TwoFactorCall?> {
        try callWrapper(fun: GA_twofactor_call(self.optr))
        var next: OpaquePointer? = nil
        try callWrapper(fun: GA_twofactor_next_call(self.optr, &next))
        let next_: TwoFactorCall? = next == nil ? nil : TwoFactorCall(optr: next!, parent: self)
        return Promise<TwoFactorCall?> { seal in seal.fulfill(next_) }
    }
}

fileprivate class FFIContext {
    var data: [String: Any]?
}

public class Session {
    private typealias EventHandler = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<Int8>?) -> Void

    private let eventHandler : EventHandler = { (o: UnsafeMutableRawPointer?, p: UnsafeMutablePointer<Int8>?) -> Void in
        defer {
            GA_destroy_string(p!)
        }
        let context : FFIContext = Unmanaged.fromOpaque(o!).takeRetainedValue()
        context.data = convertJSONBytesToDict(p!)
    }

    private let blocksFFIContext = FFIContext()

    private func subscribeToTopic(topic: String, context: FFIContext) throws -> Void {
        let opaqueContext = UnsafeMutableRawPointer(Unmanaged.passRetained(context).toOpaque())
        try callWrapper(fun: GA_subscribe_to_topic_as_json(session, topic, eventHandler, opaqueContext))
    }

    private var session: OpaquePointer? = nil

    public init() throws {
        try callWrapper(fun: GA_create_session(&session))
    }

    deinit {
        GA_destroy_session(session)
    }

    public func connect(network: Network, debug: Bool = false) throws {
        try callWrapper(fun: GA_connect(session, network.rawValue, UInt32(debug ? GA_TRUE : GA_FALSE)))

        //try subscribeToTopic(topic: "com.greenaddress.blocks", context: blocksFFIContext)
    }

    public func connectWithProxy(network: Network, proxy_uri: String, use_tor: Bool, debug: Bool = false) throws {
        try callWrapper(fun: GA_connect_with_proxy(session, network.rawValue, proxy_uri, UInt32(use_tor ? GA_USE_TOR : GA_NO_TOR),
                                                    UInt32(debug ? GA_TRUE : GA_FALSE)))

        //try subscribeToTopic(topic: "com.greenaddress.blocks", context: blocksFFIContext)
    }

    public func registerUser(mnemonic: String) throws {
        try callWrapper(fun: GA_register_user(session, mnemonic))
    }

    public func login(mnemonic: String) throws {
        try callWrapper(fun: GA_login(session, mnemonic))
    }

    public func loginWithPin(pin: String, pin_data:String) throws {
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_convert_string_to_json(pin_data, &result))
        try callWrapper(fun: GA_login_with_pin(session, pin, result))
        defer {
            GA_destroy_json(result)
        }
    }

    public func loginWatchOnly(username: String, password: String) throws {
        try callWrapper(fun: GA_login_watch_only(session, username, password))
    }

    public func removeAccount(twofactor_data: [String: Any]) throws {
        var twofactor_json: OpaquePointer = try convertDictToJSON(dict: twofactor_data)
        try callWrapper(fun: GA_remove_account(session, twofactor_json))
        defer {
            GA_destroy_json(twofactor_json)
        }
    }

    public func createSubaccount(details: [String: Any]) throws -> [String: Any]? {
        var details_json: OpaquePointer = try convertDictToJSON(dict: details)
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_create_subaccount(session, details_json, &result))
        defer {
            GA_destroy_json(details_json)
            GA_destroy_json(result)
        }
        return try convertOpaqueJsonToDict(o: result!)
    }

    public func getSubaccounts() throws -> [String: Any]? {
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_get_subaccounts(session, &result))
        defer {
            GA_destroy_json(result)
        }
        return try convertOpaqueJsonToDict(o: result!)
    }

    public func getTransactions(subaccount: UInt32, page: UInt32) throws -> [String: Any]? {
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_get_transactions(session, subaccount, page, &result))
        defer {
            GA_destroy_json(result)
        }
        return try convertOpaqueJsonToDict(o: result!)
    }

    public func getUnspentOutputs(subaccount: UInt32, num_confs: UInt32) throws -> [String: Any]? {
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_get_unspent_outputs(session, subaccount, num_confs, &result))
        defer {
            GA_destroy_json(result)
        }
        return try convertOpaqueJsonToDict(o: result!)
    }

    public func getReceiveAddress(subaccount: UInt32) throws -> String {
        var buff: UnsafeMutablePointer<Int8>? = nil
        try callWrapper(fun: GA_get_receive_address(session, subaccount, GA_ADDRESS_TYPE_DEFAULT, &buff))
        defer {
            GA_destroy_string(buff)
        }
        return String(cString: buff!)
    }

    public func getBalance(subaccount: UInt32, numConfs: UInt32) throws -> [String: Any]? {
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_get_balance(session, subaccount, numConfs, &result))
        defer {
            GA_destroy_json(result)
        }

        return try convertOpaqueJsonToDict(o: result!)
    }

    public func getAvailableCurrencies() throws -> [String: Any]? {
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_get_available_currencies(session, &result))
        defer {
            GA_destroy_json(result)
        }
        return try convertOpaqueJsonToDict(o: result!)
    }

    public func setPin(mnemonic: String, pin: String, device: String) throws -> String? {
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_set_pin(session, mnemonic, pin, device, &result))
        defer {
            GA_destroy_json(result)
        }
        return try convertOpaqueJsonToString(o: result!)
    }

    public func getTwoFactorConfig() throws -> [String: Any]? {
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_get_twofactor_config(session, &result))
        defer {
            GA_destroy_json(result)
        }
        return try convertOpaqueJsonToDict(o: result!)
    }

    func toCStr(strings: [String]) -> UnsafeMutablePointer<UnsafePointer<Int8>?> {
        let copies = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: strings.count)
        copies.initialize(to: nil, count: strings.count)
        let arr = strings.map { str -> UnsafePointer<Int8>? in
            var buff: UnsafeMutablePointer<Int8>? = nil
            GA_copy_string(str, &buff)
            return UnsafePointer<Int8>(buff!)
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

    public func convertAmount(input: [String: Any]) throws -> [String: Any]? {
        var result: OpaquePointer? = nil
        var input_json: OpaquePointer = try convertDictToJSON(dict: input)
        defer {
            GA_destroy_json(input_json)
            GA_destroy_json(result)
        }
        try callWrapper(fun: GA_convert_amount(session, input_json, &result));
        return try convertOpaqueJsonToDict(o: result!)
    }

    public func send(subaccount: UInt32, addrAmt: [(String, UInt64)], feeRate: UInt64, sendAll: Bool, twofactor_data: [String: Any]) throws -> [String: Any]? {
        var result: OpaquePointer? = nil
        var twofactor_json: OpaquePointer = try convertDictToJSON(dict: twofactor_data)
        let addresses = toCStr(strings: addrAmt.map { $0.0 })
        defer {
            clearCStr(copies: addresses, count: addrAmt.count)
            GA_destroy_json(twofactor_json)
            GA_destroy_json(result)
        }
        try callWrapper(fun: GA_send(session, subaccount, addresses, addrAmt.count, addrAmt.map { $0.1 }, addrAmt.count, feeRate, UInt32(sendAll ? GA_TRUE : GA_FALSE), twofactor_json, &result))
        return try convertOpaqueJsonToDict(o: result!)
    }

    public func sendNlocktimes() throws -> Void {
        try callWrapper(fun: GA_send_nlocktimes(session))
    }

    public func setTransactionMemo(txhash_hex: String, memo: String, memo_type: UInt32) throws -> Void {
        try callWrapper(fun: GA_set_transaction_memo(session, txhash_hex, memo, memo_type))
    }

    public func changeSettingsPricingSource(currency: String, exchange: String) throws -> Void {
        try callWrapper(fun: GA_change_settings_pricing_source(session, currency, exchange))
    }


    public func getSystemMessage() throws -> String {
        var buff: UnsafeMutablePointer<Int8>? = nil
        try callWrapper(fun: GA_get_system_message(session, &buff))
        defer {
            GA_destroy_string(buff)
        }
        return String(cString: buff!)
    }

    public func ackSystemMessage(message: String) throws -> Void {
        try callWrapper(fun: GA_ack_system_message(session, message))
    }

    public func setEmail(email: String) throws -> TwoFactorCall {
        var optr: OpaquePointer? = nil;
        try callWrapper(fun: GA_twofactor_set_email(session, email, &optr));
        return TwoFactorCall(optr: optr!);
    }

    public func enableTwoFactor(factor: String, data: String) throws -> TwoFactorCall {
        var optr: OpaquePointer? = nil;
        try callWrapper(fun: GA_twofactor_enable(session, factor, data, &optr));
        return TwoFactorCall(optr: optr!);
    }

    public func disableTwoFactor(factor: String) throws -> TwoFactorCall {
        var optr: OpaquePointer? = nil;
        try callWrapper(fun: GA_twofactor_disable(session, factor, &optr));
        return TwoFactorCall(optr: optr!);
    }

    public func getTransactionDetails(txhash: String) throws -> [String: Any]? {
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_get_transaction_details(session, txhash, &result))
        defer {
            GA_destroy_json(result)
        }
        return try convertOpaqueJsonToDict(o: result!)
    }

    public func getFeeEstimates() throws -> [String: Any]? {
        var result: OpaquePointer? = nil
        try callWrapper(fun: GA_get_fee_estimates(session, &result))
        defer {
            GA_destroy_json(result)
        }
        return try convertOpaqueJsonToDict(o: result!)
    }

    public func getMnemmonicPassphrase(password: String) throws -> String {
        var buff: UnsafeMutablePointer<Int8>? = nil
        try callWrapper(fun: GA_get_mnemonic_passphrase(session, password, &buff))
        defer {
            GA_destroy_string(buff)
        }
        return String(cString: buff!)
    }
}

public func generateMnemonic(lang: String) throws -> String {
    var buff : UnsafeMutablePointer<Int8>? = nil
    guard GA_generate_mnemonic(lang, &buff) == GA_OK else {
        throw GaError.GenericError
    }
    defer {
        GA_destroy_string(buff)
    }

    return String(cString: buff!)
}

public func validateMnemonic(lang: String, mnemonic: String) -> Bool {
    return GA_validate_mnemonic(lang, mnemonic) == GA_TRUE
}

public func parseBitcoinUri(uri: String) throws -> [String: Any]? {
    var result: OpaquePointer? = nil
    try callWrapper(fun: GA_parse_bitcoin_uri(uri, &result))
    defer {
        GA_destroy_json(result)
    }
    return try convertOpaqueJsonToDict(o: result!)
}

public func retry<T>(session: Session,
                     network: Network,
                     maxRetryCount: UInt = 3,
                     delay: DispatchTimeInterval = .seconds(2),
                     on: DispatchQueue = DispatchQueue.global(qos : .background),
                     mnemonic: String? = nil,
                     _ fun: @escaping () -> Promise<T>) -> Promise<T> {
    var attempts = 0
    func retry_() -> Promise<T> {
        attempts += 1
        return fun().recover { error -> Promise<T> in
            guard attempts < maxRetryCount && error as! GaError == GaError.ReconnectError else { throw error }
            return after(delay).then(on: on) {
                return retry(session: session, network: network, on: on) { wrap { try session.connect(network: network, debug: true) } }
            }.then(on: on, retry_)
        }
    }
    return retry_()
}

public func wrap<T>(_ fun: @escaping () throws -> T) -> Promise<T> {
    return Promise<T> { seal in
        do {
            seal.fulfill(try fun())
        } catch GaError.ReconnectError {
            seal.reject(GaError.ReconnectError)
        } catch GaError.TimeoutError {
            seal.reject(GaError.TimeoutError)
        } catch {
            seal.reject(GaError.GenericError)
        }
    }
}
