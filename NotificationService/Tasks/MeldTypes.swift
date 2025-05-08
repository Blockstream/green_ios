import Foundation

// MARK: - Meld Notification Types
public enum MeldNotificationType: String, Codable {
    case transactionSettling = "TRANSACTION_CRYPTO_TRANSFERRING"
}

// MARK: - Meld Event
public struct MeldEvent: Codable {
    let eventType: String
    let eventId: String
    let timestamp: String
    let accountId: String
    let version: String
    let payload: MeldTransactionPayload
}

// MARK: - Meld Transaction Payload
public struct MeldTransactionPayload: Codable {
    let accountId: String
    let paymentTransactionId: String
    let customerId: String
    let externalCustomerId: String?
    let externalSessionId: String?
    let paymentTransactionStatus: String
}
