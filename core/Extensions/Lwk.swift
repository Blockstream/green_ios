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
    public var lastState: String? {
        let data = data?.data(using: .utf8, allowLossyConversion: false)
        let dict = try? JSONSerialization.jsonObject(with: data ?? Data(), options: []) as? [String: Any]
        return dict?["last_state"] as? String
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
        case .Amp2HttpError(url: let url, status: let status, body: let body):
            return "Amp2 \(status) error: \(body ?? "")"
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

extension WalletTxOut {
    func toInputOutput(isOutput: Bool) -> TxInputOutput {
        let secrets = unblinded()
        let isInternal = extInt() == Chain.internal
        return TxInputOutput(
            address: address().description,
            isChange: isOutput && isInternal,
            satoshi: secrets.value().int64(),
            isRelevant: true,
            isInternal: isInternal,
            isOutput: isOutput,
            assetId: secrets.asset(),
            amountBlinder: secrets.valueBf(),
            assetBlinder: secrets.assetBf()
        )
    }
}
