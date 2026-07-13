import Foundation

public struct TxUnblindedData: Codable {
    let version: Int
    let txid: String
    let type: TransactionType
    let inputs: [TxInputUnblindedData]
    let outputs: [TxOutputUnblindedData]
}
