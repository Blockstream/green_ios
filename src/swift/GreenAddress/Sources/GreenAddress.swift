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

public class Session {
    var session: OpaquePointer? = nil

    public init() throws {
        if GA_create_session(&session) == GA_ERROR {
            throw GaError.GenericError
        }
    }

    deinit {
        GA_destroy_session(session)
    }

    public func connect(network: Network, debug: Bool = false) throws {
        if GA_connect(session, network.rawValue, debug ? GA_TRUE : GA_FALSE) == GA_ERROR {
            throw GaError.GenericError
        }
    }

    public func registerUser(mnemonic: String) throws {
        if GA_register_user(session, mnemonic) == GA_ERROR {
            throw GaError.GenericError
        }
    }

    public func login(mnemonic: String) throws {
        if GA_login(session, mnemonic) == GA_ERROR {
            throw GaError.GenericError
        }
    }

    public func getTxList(begin: Date, end: Date, subaccount: Int) throws -> [String: Any]? {
        var txs: OpaquePointer? = nil
        if GA_get_tx_list(session, Int(begin.timeIntervalSince1970), Int(end.timeIntervalSince1970), subaccount, 0, 0, String(), &txs) == GA_ERROR {
            throw GaError.GenericError
        }
        defer {
            GA_destroy_tx_list(txs)
        }

        var bytes : UnsafeMutablePointer<Int8>? = nil
        if GA_convert_tx_list_to_json(txs, &bytes) == GA_ERROR {
            throw GaError.GenericError
        }
        defer {
            GA_destroy_string(bytes)
        }

        var dict: [String: Any]? = nil;

        let json: String = String(cString: bytes!)
        if let data = json.data(using: .utf8) {
            do {
                dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                return nil
            }
        }

        return dict
    }

    public func getReceiveAddress() -> String? {
        var bytes : UnsafeMutablePointer<Int8>? = nil
        if GA_get_receive_address(session, GA_ADDRESS_TYPE_P2SH, 0, &bytes) == GA_ERROR {
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
    if GA_generate_mnemonic(lang, &bytes) == GA_ERROR {
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
