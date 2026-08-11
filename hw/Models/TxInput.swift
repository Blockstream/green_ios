import Foundation

public struct TxInput: Codable {
    enum CodingKeys: String, CodingKey {
        case inputTx = "input_tx"
        case script = "script"
        case isWitness = "is_witness"
        case path = "path"
        case satoshi = "satoshi"
        case valueCommitment = "value_commitment"
        case aeHostEntropy = "ae_host_entropy"
        case aeHostCommitment = "ae_host_commitment"
    }
    let isWitness: Bool
    let inputTx: Data?
    let script: Data?
    let satoshi: UInt64?
    let valueCommitment: Data?
    let path: [Int]?
    var aeHostEntropy: Data?
    let aeHostCommitment: Data?
}
