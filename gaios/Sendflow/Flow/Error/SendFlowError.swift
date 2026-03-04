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

    func description() -> String {
        switch self {
        case .noAvailableSubaccounts:
            return "No available subaccounts"
        case .invalidPaymentTarget:
            return "id_invalid_address"
        case .failedToBuildTransaction:
            return "Failed to build transaction"
        case .wrongSubaccount:
            return "id_invalid_address"
        case .wrongAssetId(let ticker):
            return "Payment URI is for \(ticker)."
        case .insufficientFunds:
            return "id_insufficient_funds"
        case .invalidSession:
            return "Invalid session"
        case .generic(let msg):
            return msg.localized
        case .serviceUnavailable:
            return "Service temporary unavailable"
        case .gdkError(let msg):
            return msg.localized
        case .invalidAmount(let msg):
            return msg.localized
        case .lwkError(let lwkError):
            return lwkError.description().localized
        }
    }
}
