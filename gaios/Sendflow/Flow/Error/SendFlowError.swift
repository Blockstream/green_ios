import LiquidWalletKit

enum SendFlowError: Error, Sendable, Equatable {
    case noAvailableSubaccounts
    case invalidPaymentTarget
    case failedToBuildTransaction
    case invalidSession
    case wrongSubaccount
    case insufficientFunds
    case wrongAssetId(String)
    case invalidAmount(String)
    case generic(String)
    case gdkError(String)
    case lwkError(LwkError)
    case serviceUnavailable
    case unsupportedInJadeCore

    func description() -> String {
        switch self {
        case .noAvailableSubaccounts:
            return "id_insufficient_funds"
        case .invalidPaymentTarget:
            return "id_invalid_address"
        case .failedToBuildTransaction:
            return "id_failed_to_build_transaction"
        case .wrongSubaccount:
            return "id_invalid_address"
        case .wrongAssetId(let ticker):
            return "Payment URI is for \(ticker)."
        case .insufficientFunds:
            return "id_insufficient_funds"
        case .invalidSession:
            return "id_invalid_session"
        case .generic(let msg):
            return msg.localized
        case .serviceUnavailable:
            return "id_service_temporarily_unavailable"
        case .gdkError(let msg):
            return msg.localized
        case .invalidAmount(let msg):
            return msg.localized
        case .lwkError(let lwkError):
            return lwkError.description().localized
        case .unsupportedInJadeCore:
            return "Swaps are not enabled for this wallet".localized
        }
    }
}
