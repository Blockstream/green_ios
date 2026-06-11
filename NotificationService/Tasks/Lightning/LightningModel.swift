import Foundation
import core

public enum LightningEventType: String, Codable {
    case incomingPayment = "incoming_payment"
    case nodeStuck = "node_stuck"
    case userSessionStart = "user_session_start"
}

public struct LightningEvent: Codable {
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case nodeId = "node_id"
        case walletHashedId = "wallet_hashed_id"
        case eventType = "event_type"
        case timestamp
    
        case paymentHash = "payment_hash"
        case amountMsat = "amount_msat"
        case bolt11
        case label
        
        case blockheight
        case headheight
        case lag
        
        case sessionId = "session_id"
        case region
    }
    
    let eventId: String?
    let nodeId: String?
    let walletHashedId: String?
    let eventType: LightningEventType
    let timestamp: String?
    
    let paymentHash: String?
    let amountMsat: String?
    let bolt11: String?
    let label: String?
    
    let blockheight: String?
    let headheight: String?
    let lag: String?
    
    let sessionId: String?
    let region: String?
    
    var displayMessage: String? {
        switch eventType {
        case .incomingPayment:
            if let msatStr = amountMsat, let msat = UInt64(msatStr) {
                let sats = msat / 1000
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                let formattedSats = formatter.string(from: NSNumber(value: sats)) ?? "\(sats)"
                return "You received \(formattedSats) sats!"
            }
            logger.info("LightningEvent: incoming_payment received but amountMsat is nil or invalid")
            return "Payment received successfully!"
            
        case .nodeStuck:
            return "Your node is having sync issues"
            
        case .userSessionStart:
            return "A new session started on your node"
        }
    }
}
