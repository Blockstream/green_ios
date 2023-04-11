import Foundation
import RxSwift
import RxBluetoothKit
import CoreBluetooth
import greenaddress

final public class Ledger: LedgerCommands, HWProtocol {

    public static let shared = Ledger()
    let SIGHASH_ALL: UInt8 = 1

    // swiftlint:disable:next function_parameter_count
    public func signTransaction(network: String, tx: [String: Any], inputs: [[String: Any]], outputs: [[String: Any]],
                         transactions: [String: String], useAeProtocol: Bool) -> Observable<[String: Any]> {
        return signSW(tx: tx, inputs: inputs, outputs: outputs)
            .compactMap { sigs in
                return ["signatures": sigs, "signer_commitments": []]
            }
    }

    public func signSW(tx: [String: Any], inputs: [[String: Any]], outputs: [[String: Any]]) -> Observable<[String]> {
        let hwInputs = inputs.map { input -> [String: Any] in
            let bytes = inputBytes(input, isSegwit: true)!
            let sequence = (input["sequence"] as? UInt)!.uint32LE()
            return ["value": bytes, "sequence": Data(sequence), "trusted": false, "segwit": true]
        }
        // Prepare the pseudo transaction
        // Provide the first script instead of a null script to initialize the P2SH confirmation logic
        let version = tx["transaction_version"] as? UInt
        let prevoutScript = inputs.first?["prevout_script"] as? String
        let script0 = prevoutScript!.hexToData()
        let locktime = tx["transaction_locktime"] as? UInt
        return startUntrustedTransaction(txVersion: version!, newTransaction: true, inputIndex: 0, usedInputList: hwInputs, redeemScript: script0, segwit: true)
        .flatMap { _ -> Observable<[String: Any]> in
            let bytes = self.outputBytes(outputs)
            return self.finalizeInputFull(data: bytes!)
        }.flatMap { _ -> Observable<[Data]> in
            return self.signSWInputs(hwInputs: hwInputs, inputs: inputs, version: version!, locktime: locktime!)
        }.flatMap { sigs -> Observable<[String]> in
            var strings = [String]()
            for sig in sigs {
                let string = Array(sig).map { String(format: "%02hhx", $0) }.joined()
                strings.append(string)
            }
            return Observable.just(strings)
        }
    }

    public func signSWInputs(hwInputs: [[String: Any]], inputs: [[String: Any]], version: UInt, locktime: UInt) -> Observable<[Data]> {
        let allObservables = hwInputs
            .enumerated()
            .map { hwInput -> Observable<Data> in
                return Observable.just(hwInput.element)
                    .flatMap { _ in self.signSWInput(hwInput: hwInput.element, input: inputs[hwInput.offset], version: version, locktime: locktime) }
                    .asObservable()
                    .take(1)
        }
        return Observable.concat(allObservables).reduce([], accumulator: { result, element in
            result + [element]
        })
    }

    public func signSWInput(hwInput: [String: Any], input: [String: Any], version: UInt, locktime: UInt) -> Observable<Data> {
        let prevoutScript = input["prevout_script"] as? String
        let script = prevoutScript!.hexToData()
        return startUntrustedTransaction(txVersion: version, newTransaction: false, inputIndex: 0, usedInputList: [hwInput], redeemScript: script, segwit: true)
        .flatMap { _ -> Observable <Data> in
            let paths = input["user_path"] as? [Int64]
            let userPaths: [Int] = paths!.map { Int($0) }
            return self.untrustedHashSign(privateKeyPath: userPaths, pin: "0", lockTime: locktime, sigHashType: self.SIGHASH_ALL)
        }
    }

    public func signMessage(path: [Int]?,
                     message: String?,
                     useAeProtocol: Bool?,
                     aeHostCommitment: String?,
                     aeHostEntropy: String?)
    -> Observable<(signature: String?, signerCommitment: String?)> {
        return signMessagePrepare(path: path ?? [], message: message?.data(using: .utf8) ?? Data())
            .flatMap { _ in self.signMessageSign(pin: [0])}
            .compactMap { res in
                let signature = res["signature"] as? [UInt8]
                let hexSig = signature!.map { String(format: "%02hhx", $0) }.joined()
                return (signature: hexSig, signerCommitment: nil)
        }
    }

    public func xpubs(network: String, paths: [[Int]]) -> Observable<[String]> {
        let allObservables = paths
            .map {
                Observable.just($0)
                    .flatMap { self.xpubs(network: network, path: $0) }
                    .asObservable()
                    .take(1)
        }
        return Observable.concat(allObservables)
        .reduce([], accumulator: { result, element in
            result + [element]
        })
    }

    public func xpubs(network: String, path: [Int]) -> Observable<String> {
        let isMainnet = ["mainnet", "liquid"].contains(network)
        return self.pubKey(path: path)
            .flatMap { data -> Observable<String> in
                let chainCode = Array((data["chainCode"] as? Data)!)
                let publicKey = Array((data["publicKey"] as? Data)!)
                let compressed = try! compressPublicKey(publicKey)
                let base58 = try! bip32KeyToBase58(isMainnet: isMainnet, pubKey: compressed, chainCode: chainCode)
                return Observable.just(base58)
        }
    }

    public func newReceiveAddress(chain: String,
                                  mainnet: Bool,
                                  multisig: Bool,
                                  chaincode: String?,
                                  recoveryPubKey: String?,
                                  walletPointer: UInt32?,
                                  walletType: String?,
                                  path: [UInt32],
                                  csvBlocks: UInt32) -> Observable<String> {
        return Observable.error(HWError.Abort(""))
    }

    // Liquid not support
    public func getBlindingKey(scriptHex: String) -> Observable<String?> {
        return Observable.error(HWError.Abort(""))
    }

    public func getBlindingNonce(pubkey: String, scriptHex: String) -> Observable<String?> {
        return Observable.error(HWError.Abort(""))
    }

    // swiftlint:disable:next function_parameter_count
    public func signLiquidTransaction(network: String, tx: [String: Any], inputs: [[String: Any]], outputs: [[String: Any]], transactions: [String: String], useAeProtocol: Bool) -> Observable<[String: Any]> {
        return Observable.error(HWError.Abort(""))
    }

    public func nonces(bscripts: [[String: Any]]) -> Observable<[String?]> {
        return Observable.error(HWError.Abort(""))
    }

    public func blindingKey(scriptHex: String) -> Observable<String?> {
        return Observable.error(HWError.Abort(""))
    }
    public func getSharedNonce(pubkey: String, scriptHex: String) -> Observable<String?> {
        return Observable.error(HWError.Abort(""))
    }

    public func getMasterBlindingKey() -> Observable<String> {
        return Observable.error(HWError.Abort(""))
    }
}