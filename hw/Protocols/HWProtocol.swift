import Foundation
import UIKit
import PromiseKit
import RxSwift

public protocol HWProtocol {

    func xpubs(network: String, paths: [[Int]]) -> Observable<[String]>

    func signMessage(path: [Int]?,
                     message: String?,
                     useAeProtocol: Bool?,
                     aeHostCommitment: String?,
                     aeHostEntropy: String?)
    -> Observable<(signature: String?, signerCommitment: String?)>

    // swiftlint:disable:next function_parameter_count
    func signTransaction(network: String,
                         tx: [String: Any],
                         inputs: [[String: Any]],
                         outputs: [[String: Any]],
                         transactions: [String: String],
                         useAeProtocol: Bool) -> Observable<[String: Any]>

    func newReceiveAddress(chain: String,
                                  mainnet: Bool,
                                  multisig: Bool,
                                  chaincode: String?,
                                  recoveryPubKey: String?,
                                  walletPointer: UInt32?,
                                  walletType: String?,
                                  path: [UInt32],
                                  csvBlocks: UInt32) -> Observable<String>

    func getMasterBlindingKey() -> Observable<String>

    // Liquid calls
    func getBlindingKey(scriptHex: String) -> Observable<String?>
    func getSharedNonce(pubkey: String, scriptHex: String) -> Observable<String?>

    // swiftlint:disable:next function_parameter_count
    func signLiquidTransaction(network: String,
                               tx: [String: Any],
                               inputs: [[String: Any]],
                               outputs: [[String: Any]],
                               transactions: [String: String],
                               useAeProtocol: Bool) -> Observable<[String: Any]>
}