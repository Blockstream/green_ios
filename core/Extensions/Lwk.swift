import LiquidWalletKit
import Foundation

extension BoltzSwap {
    public var type: BoltzSwapTypes? {
        let data = data?.data(using: .utf8, allowLossyConversion: false)
        let dict = try? JSONSerialization.jsonObject(with: data ?? Data(), options: []) as? [String: Any]
        if let swapType = dict?["swap_type"] as? String {
            return BoltzSwapTypes(rawValue: swapType)
        }
        return nil
    }
}

extension LwkError {
    public func description() -> String {
        switch self {
        case .Generic(msg: let msg):
            return msg.replacingOccurrences(of: "BoltzApi(HTTP(\"\\\"", with: "").replacingOccurrences(of: "\\\"\"))", with: "")
        case .PoisonError(msg: _):
            return "An internal error occurred. Please try again or contact support."
        case .MagicRoutingHint(_, _, _):
            return "A routing error occurred. Please try again."
        case .SwapExpired(_, _):
            return "This swap has expired. Please start a new one."
        case .NoBoltzUpdate:
            return "The swap service is not responding. Please try again later."
        case .ObjectConsumed:
            return "An internal error occurred. Please restart the app and try again."
        case .BoltzBackendHttpError(status: let status, error: _):
            return "A server error occurred (code \(status)). Please try again later."
        }
    }
}

extension PaymentState {
    public var localized: String {
        switch self {
        case PaymentState.success:
            return "success"
        case PaymentState.failed:
            return "failed"
        case PaymentState.continue:
            return "continue"
        }
    }
}
