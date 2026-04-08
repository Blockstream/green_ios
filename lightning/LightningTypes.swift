import GreenlightSDK
import Foundation

public struct LightningInvoice: Codable {
    public let bolt11: String?
    public let amountSatoshi: UInt64?
    public let timestamp: UInt64?
    public let expiry: UInt64?
    public let paymentHash: String?
    public let description: String?

    public static func from(invoice: Invoice) -> LightningInvoice {
        return .init(
            bolt11: invoice.bolt11,
            amountSatoshi: invoice.amountMsat?.satoshi,
            timestamp: invoice.paidAt ?? 0,
            expiry: invoice.expiresAt,
            paymentHash: invoice.paymentHash,
            description: invoice.description)
    }
}

public struct LightningReceivePayment: Codable {
    public let invoice: LightningInvoice
    public let openingFeeSatoshi: UInt64
}

public struct SendResult {
    public let status: PayStatus
    public let preimage: String
    public let amountMsat: UInt64
    public let feeMsat: UInt64
}

public struct OnchainSendResult: Codable {
    public let txid: String
}
