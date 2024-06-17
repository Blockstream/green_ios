import Foundation
import gdk
import hw
import SwiftCBOR
/*
public protocol QRJadeGDKRequest: AnyObject {
    func httpRequest(params: [String: Any]) async -> [String: Any]?
    func urlValidation(urls: [String]) async -> Bool
    func bcurEncode(params: BcurEncodeParams) async throws -> BcurEncodedData
}

public protocol QRJadeResolver: AnyObject {
    func read() async throws -> BcurDecodedData
    func write(bcur: BcurEncodedData) async throws
}*/
/*
public class QRJade: HWProtocol {
    public func getMasterBlindingKey(onlyIfSilent: Bool) async throws -> String {
        fatalError()
    }
    
    public func xpubs(network: String, paths: [[Int]]) async throws -> [String] {
        fatalError()
    }
    
    public func signMessage(_ params: hw.HWSignMessageParams) async throws -> hw.HWSignMessageResult {
        fatalError()
    }
    
    public func signTransaction(network: String, params: hw.HWSignTxParams) async throws -> hw.HWSignTxResponse {
        fatalError()
    }
    
    // swiftlint:disable function_parameter_count
    public func newReceiveAddress(chain: String, mainnet: Bool, multisig: Bool, chaincode: String?, recoveryPubKey: String?, walletPointer: UInt32?, walletType: String?, path: [UInt32], csvBlocks: UInt32) async throws -> String {
        fatalError()
    }
    
    public func getMasterBlindingKey() async throws -> String {
        fatalError()
    }
    
    public func getBlindingKey(scriptHex: String) async throws -> String {
        fatalError()
    }
    
    public func getSharedNonce(pubkey: String, scriptHex: String) async throws -> String {
        fatalError()
    }
    
    public func getBlindingFactors(params: hw.HWBlindingFactorsParams) async throws -> hw.HWBlindingFactorsResult {
        fatalError()
    }
    
    public func signLiquidTransaction(network: String, params: hw.HWSignTxParams) async throws -> hw.HWSignTxResponse {
        fatalError()
    }
    

    public var gdkRequestDelegate: QRJadeGDKRequest
    public var qrJadeResolver: QRJadeResolver
    
    public init(gdkRequestDelegate: QRJadeGDKRequest, qrJadeResolver: QRJadeResolver) {
        self.gdkRequestDelegate = gdkRequestDelegate
        self.qrJadeResolver = qrJadeResolver
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
    
    public func auth() async throws {
        let res = try await qrJadeResolver.read()
        let res1 = try await handshakeInit(bcur: res)
        try await qrJadeResolver.write(bcur: res1)
        let res2 = try await qrJadeResolver.read()
        let res3 = try await handshakeReply(bcur: res2)
        try await qrJadeResolver.write(bcur: res3)
    }
    
    public func handshakeInit(bcur: BcurDecodedData) async throws -> BcurEncodedData {
        if bcur.urType != "jade-pin" {
            throw HWError.Abort("Invalid message")
        }
        guard let data = bcur.data?.hexToData() else {
            throw HWError.Abort("Invalid message")
        }
        
        let response = try CodableCBORDecoder().decode(JadeResponse<JadeAuthResponse<String>>.self, from: data)
        guard let result = response.result else {
            throw HWError.Abort("Invalid message")
        }
        let httpRequest: JadeHttpRequest<String> = result.httpRequest
        let cmd: JadeHandshakeInit = try await self.httpRequest(httpRequest)
        let reply = JadeRequest<JadeHandshakeInit>(method: httpRequest.onReply, params: cmd)
        let params = BcurEncodeParams(urType: "jade-pin", data: reply.toCbor()?.hex)
        return try await gdkRequestDelegate.bcurEncode(params: params)
    }
    
    public func handshakeReply(bcur: BcurDecodedData) async throws -> BcurEncodedData {
        if bcur.urType != "jade-pin" {
            throw HWError.Abort("Invalid message")
        }
        guard let data = bcur.data?.hexToData() else {
            throw HWError.Abort("Invalid message")
        }
        let response = try CodableCBORDecoder().decode(JadeResponse<JadeAuthResponse<JadeHandshakeComplete>>.self, from: data)
        guard let result = response.result else {
            throw HWError.Abort("Invalid message")
        }
        let httpRequest: JadeHttpRequest<JadeHandshakeComplete> = result.httpRequest
        let cmd: JadeHandshakeCompleteReply = try await self.httpRequest(httpRequest)
        let reply = JadeRequest<JadeHandshakeCompleteReply>(method: httpRequest.onReply, params: cmd)
        let params = BcurEncodeParams(urType: "jade-pin", data: reply.toCbor()?.hex)
        return try await gdkRequestDelegate.bcurEncode(params: params)
    }
    
    public func httpRequest<T: Codable, K: Codable>(_ httpRequest: JadeHttpRequest<T>) async throws -> K {
        let httpResponse = await self.gdkRequestDelegate.httpRequest(params: httpRequest.params.toDict() ?? [:])
        if let error = httpResponse?["error"] as? String {
            throw HWError.Abort(error)
        }
        let httpResponseBody = httpResponse?["body"] as? [String: Any]
        if let decoded = K.from(httpResponseBody ?? [:]) as? K {
            return decoded
        }
        throw HWError.Abort("id_action_canceled")
    }
}*/
