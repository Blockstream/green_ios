import Foundation
import AsyncBluetooth
import Combine
import SwiftCBOR

public protocol JadeGdkRequest: AnyObject {
    func httpRequest(params: [String: Any]) async -> [String: Any]?
    func urlValidation(urls: [String]) async -> Bool
}

public class BleJadeCommands: BleJadeConnection {

    public static let FW_SERVER_HTTPS = "https://jadefw.blockstream.com"
    public static let FW_SERVER_ONION = "http://vgza7wu4h7osixmrx6e4op5r72okqpagr3w6oupgsvmim4cz3wzdgrad.onion"
    public static let PIN_SERVER_HTTPS = "https://jadepin.blockstream.com"
    public static let PIN_SERVER_ONION = "http://mrrxtq6tjpbnbm7vh5jt6mpjctn7ggyfy5wegvbeff3x7jrznqawlmid.onion"
    public static let PIN_SERVERv2_HTTPS = "https://j8d.io"

    public static let MIN_ALLOWED_FW_VERSION = "0.1.44"
    public static let FW_JADE_PATH = "/bin/jade/"
    public static let FW_JADEDEV_PATH = "/bin/jadedev/"
    public static let FW_JADE1_1_PATH = "/bin/jade1.1/"
    public static let FW_JADE1_1DEV_PATH = "/bin/jade1.1dev/"
    public static let BOARD_TYPE_JADE = "JADE"
    public static let BOARD_TYPE_JADE_V1_1 = "JADE_V1.1"
    public static let FEATURE_SECURE_BOOT = "SB"

    public let blockstreamUrls = [
        BleJadeCommands.PIN_SERVERv2_HTTPS,
        BleJadeCommands.FW_SERVER_HTTPS,
        BleJadeCommands.FW_SERVER_ONION,
        BleJadeCommands.PIN_SERVER_HTTPS,
        BleJadeCommands.PIN_SERVER_ONION]

    public weak var gdkRequestDelegate: JadeGdkRequest?

    public func version() async throws -> JadeVersionInfo {
        let res: JadeResponse<JadeVersionInfo> = try await exchange(JadeRequest<JadeEmpty>(method: "get_version_info"))
        guard let res = res.result else { throw HWError.Abort("Invalid response") }
        return res
    }

    public func addEntropy() async throws -> Bool {
        let buffer = [UInt8](repeating: 0, count: 32).map { _ in UInt8(arc4random_uniform(0xff))}
        let cmd = JadeAddEntropy(entropy: Data(buffer))
        let res: JadeResponse<Bool> = try await exchange(JadeRequest<JadeAddEntropy>(method: "add_entropy", params: cmd))
        guard let res = res.result else { throw HWError.Abort("Invalid response") }
        return res
    }

    public func xpubs(network: String, path: [Int]) async throws -> String {
        let cmd = JadeGetXpub(network: network, path: getUnsignedPath(path))
        let res: JadeResponse<String> = try await exchange(JadeRequest<JadeGetXpub>(method: "get_xpub", params: cmd))
        guard let res = res.result else { throw HWError.Abort("Invalid response") }
        return res
    }

    // Get blinding key for script
    public func getBlindingKey(scriptHex: String) async throws -> String {
        let cmd = JadeGetBlindingKey(scriptHex: scriptHex)
        let res: JadeResponse<Data> = try await exchange(JadeRequest<JadeGetBlindingKey>(method: "get_blinding_key", params: cmd))
        guard let res = res.result?.hex else { throw HWError.Abort("Invalid response") }
        return res
    }

    public func getSharedNonce(pubkey: String, scriptHex: String) async throws -> String {
        let cmd = JadeGetSharedNonce(scriptHex: scriptHex, theirPubkeyHex: pubkey)
        let res: JadeResponse<Data> = try await exchange(JadeRequest<JadeGetSharedNonce>(method: "get_shared_nonce", params: cmd))
        guard let res = res.result?.hex else { throw HWError.Abort("Invalid response") }
        return res
    }

    public func getBlindingFactor(_ params: JadeGetBlingingFactor) async throws -> Data {
        let res: JadeResponse<Data> = try await exchange(JadeRequest(method: "get_blinding_factor", params: params))
        guard let res = res.result else { throw HWError.Abort("Invalid response") }
        return res
    }

    public func getMasterBlindingKey(onlyIfSilent: Bool) async throws -> String {
        var params = JadeGetMasterBlindingKey(onlyIfSilent: onlyIfSilent)
        let res: JadeResponse<Data> = try await exchange(JadeRequest(method: "get_master_blinding_key", params: params))
        guard let res = res.result?.hex else { throw HWError.Abort("Invalid response") }
        return res
    }

    public func signLiquidTx(params: JadeSignTx) async throws -> Bool {
        let res: JadeResponse<Bool> = try await exchange(JadeRequest<JadeSignTx>(method: "sign_liquid_tx", params: params))
        guard let res = res.result else { throw HWError.Abort("Error response from initial sign_liquid_tx call: \(res.error?.message ?? "")") }
        return res
    }

    public func getReceiveAddress(_ params: JadeGetReceiveMultisigAddress) async throws -> String {
        let res: JadeResponse<String> = try await exchange(JadeRequest<JadeGetReceiveMultisigAddress>(method: "get_receive_address", params: params))
        guard let res = res.result else { throw HWError.Abort("Invalid response") }
        return res
    }

    public func getReceiveAddress(_ params: JadeGetReceiveSinglesigAddress) async throws -> String {
        let res: JadeResponse<String> = try await exchange(JadeRequest<JadeGetReceiveSinglesigAddress>(method: "get_receive_address", params: params))
        guard let res = res.result else { throw HWError.Abort("Invalid response") }
        return res
    }

    public func signMessage(_ params: JadeSignMessage) async throws -> Data {
        let res: JadeResponse<Data> = try await exchange(JadeRequest<JadeSignMessage>(method: "sign_message", params: params))
        guard let res = res.result else { throw HWError.Abort("Invalid response") }
        return res
    }

    public func signSimpleMessage(_ params: JadeSignMessage) async throws -> String {
        let res: JadeResponse<String> = try await exchange(JadeRequest<JadeSignMessage>(method: "sign_message", params: params))
        guard let res = res.result else { throw HWError.Abort("Invalid response") }
        return res
    }

    public func getSignature(_ params: JadeGetSignature) async throws -> String {
        let res: JadeResponse<String> = try await exchange(JadeRequest<JadeGetSignature>(method: "get_signature", params: params))
        guard let res = res.result else { throw HWError.Abort("Invalid response") }
        return res
    }

    func request2cbor<T: Decodable>(_ request: JadeRequest<T>)  async throws -> Data {
        guard let buffer = request.encoded else { throw HWError.Abort("Invalid message") }
        return buffer
    }

    func dict2cbor(_ request: [String: Any]) async throws -> Data {
        let inEncoded: [UInt8] = try! CBOR.encodeMap(request)
        return Data(inEncoded)
    }

    func cbor2response<K: Decodable>(_ response: Data)  async throws -> JadeResponse<K> {
        return try CodableCBORDecoder().decode(JadeResponse<K>.self, from: response)
    }

    func cbor2dict(_ response: Data)  async throws -> [String: Any?] {
        let decoded = try CBOR.decode([UInt8](response))
        let map = CBOR.getDictionary(map: decoded ?? [:])
        let dict = try CBOR.convertCBORMapToDictionary(map ?? [:])
        return dict
    }

    func exchange<T: Decodable, K: Decodable>(_ request: JadeRequest<T>) async throws -> JadeResponse<K> {
#if DEBUG
        print("=> \(request)")
#endif
        // encode request
        let request = try await request2cbor(request)
        // send request
        var res = try await exchange(request)
        // handling generic http request
        while true {
            let response = try await cbor2dict(res)
            if let error = response["error"] as? [String: Any],
               let errorCode = error["code"] as? Int,
               let errorMessage = error["message"] as? String {
                throw HWError.from(code: errorCode, message: errorMessage )
            }
            if let result = response["result"] as? [String: Any],
               let httpRequest = result["http_request"] as? [String: Any],
                let onReply = httpRequest["on-reply"] as? String {
                let httpResponse = try await makeHttpRequest(httpRequest)
                let package = [
                    "id": "\(JadeRequestId)",
                    "method": onReply,
                    "params": httpResponse
                ] as [String: Any]
                JadeRequestId += 1
                let request = try await dict2cbor(package)
        #if DEBUG
                print("=> HttpRequest : \(request.hex)")
        #endif
                res = try await exchange(request)
        #if DEBUG
                print("<= HttpResponse: \(res.hex)")
        #endif
            } else {
                break
            }
        }
        // decode response
        let response: JadeResponse<K> = try await cbor2response(res)
#if DEBUG
        print("<= \(response)")
#endif
        if let error = response.error {
            throw HWError.from(code: error.code, message: error.message)
        }
        return response
    }
    /*
    func exchange(method: String, params: [String: Any]) async throws -> [String: Any?] {
        let package = [
            "id": "\(JadeRequestId)",
            "method": method,
            "params": params
        ] as [String : Any]
        JadeRequestId += 1
        let request = try await dict2cbor(package)
#if DEBUG
        print("=> \(request)")
#endif
        let res = try await exchange(request)
        var response = try await cbor2dict(res)
#if DEBUG
        print("<= \(response)")
#endif
        return response
    }*/

    public func makeHttpRequest(_ httpRequest: [String: Any]) async throws -> [String: Any] {
        let params = httpRequest["params"] as? [String: Any]
        let urls = params?["urls"] as? [String] ?? []
        let isUrlSafe = urls.allSatisfy { url in !blockstreamUrls.filter { url.starts(with: $0) }.isEmpty }
        if !isUrlSafe {
            let validated = await gdkRequestDelegate?.urlValidation(urls: urls)
            if !(validated ?? false) {
                throw HWError.Abort("Unkwnown url")
            }
        }
        let httpResponse = await gdkRequestDelegate?.httpRequest(params: params ?? [:])
        if let error = httpResponse?["error"] as? String {
            throw HWError.Abort(error)
        }
        guard let httpResponseBody = httpResponse?["body"] as? [String: Any] else {
            throw HWError.Abort("Empty response")
        }
        return httpResponseBody
    }
}
