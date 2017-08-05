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

public class Transaction {
    public enum TransactionType {
        case Out
        case In
        case Redeposit
    }

    public class View {
        var view: OpaquePointer? = nil

        init(tx: OpaquePointer) throws {
            guard GA_tx_populate_view(tx, &view) == GA_OK else {
                throw GaError.GenericError
            }
        }

        deinit {
            GA_destroy_tx_view(view)
        }

        public func getValue() throws -> Int64 {
            var value: Int64 = 0
            guard GA_tx_view_get_value(view, &value) == GA_OK else {
                throw GaError.GenericError
            }
            return value;
        }

        public func getFee() throws -> Int64 {
            var fee: Int64 = 0
            guard GA_tx_view_get_fee(view, &fee) == GA_OK else {
                throw GaError.GenericError
            }
            return fee;
        }

        public func getHash() throws -> String {
            var bytes: UnsafePointer<Int8>? = nil
            guard GA_tx_view_get_hash(view, &bytes) == GA_OK else {
                throw GaError.GenericError
            }
            return String(cString: bytes!)
        }

        public func getCounterparty() throws -> String {
            var bytes: UnsafePointer<Int8>? = nil
            guard GA_tx_view_get_counterparty(view, &bytes) == GA_OK else {
                throw GaError.GenericError
            }
            return String(cString: bytes!)
        }

        public func getDoubleSpentBy() throws -> String {
            var bytes: UnsafePointer<Int8>? = nil
            guard GA_tx_view_get_double_spent_by(view, &bytes) == GA_OK else {
                throw GaError.GenericError
            }
            return String(cString: bytes!)
        }

        public func getInstant() throws -> Bool {
            var instant: Int32 = 0
            guard GA_tx_view_get_instant(view, &instant) == GA_OK else {
                throw GaError.GenericError
            }
            return instant != 0
        }

        public func getReplaceable() throws -> Bool {
            var replaceable: Int32 = 0
            guard GA_tx_view_get_replaceable(view, &replaceable) == GA_OK else {
                throw GaError.GenericError
            }
            return replaceable != 0
        }

        public func getIsSpent() throws -> Bool {
            var isSpent: Int32 = 0
            guard GA_tx_view_get_is_spent(view, &isSpent) == GA_OK else {
                throw GaError.GenericError
            }
            return isSpent != 0
        }

        public func getType() throws -> TransactionType {
            var type: Int32 = 0
            guard GA_tx_view_get_type(view, &type) == GA_OK else {
                throw GaError.GenericError
            }
            switch type {
                case 0:
                    return TransactionType.Out
                case 1:
                    return TransactionType.In
                case 2:
                    return TransactionType.Redeposit
                default:
                    throw GaError.GenericError
            }
        }
    }

    var tx: OpaquePointer? = nil;

    public init(tx: OpaquePointer) {
        self.tx = tx
    }

    deinit {
        GA_destroy_tx(tx)
    }

    public func getView() throws -> View {
        return try! View(tx: tx!)
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

        var count: Int = 0;
        guard GA_tx_list_get_size(txs, &count) == GA_OK else {
            throw GaError.GenericError
        }

        var txss = [Transaction]()
        for i in 0..<count {
            var tx: OpaquePointer? = nil;
            guard GA_tx_list_get_tx(txs, i, &tx) == GA_OK else {
                throw GaError.GenericError;
            }
            txss.append(Transaction(tx: tx!))
        }

        return txss
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
