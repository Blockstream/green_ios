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
        case .PoisonError(msg: let msg):
            return "Poison Error \(msg)"
        case .MagicRoutingHint(address: let address, amount: let amount, uri: let uri):
            return "Magic Routing Hint for \(uri): \(address) \(amount)"
        case .SwapExpired(swapId: let swapId, status: let status):
            return "Swap \(swapId) expired: \(status)"
        case .NoBoltzUpdate:
            return "No Boltz Update"
        case .ObjectConsumed:
            return "Object Consumed"
        case .BoltzBackendHttpError(status: let status, error: let error):
            return "Http error \(status): \(error ?? "")"
        case .GenericWithSwapId(msg: let msg, swapId: let swapId):
            return "Swap \(swapId) error: \(msg)"
        case .EsploraHttpError(
            url: _,
            status: let status,
            body: let body
        ):
            return "Esplora \(status) error: \(body ?? "")"
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
