import Foundation
import gdk
import hw
import SwiftCBOR
import core
import greenaddress


class QRJadeResolverImpl: QRJadeResolver {
    func read() async throws -> Data {
        Data()
    }
    
    func write(_ data: Data) async throws {
        
    }
    
}

class QRJadeManager {
    
    var oracle: String? = nil
    var pinServerSession: SessionManager
    var network: NetworkSecurityCase
    var device: Jade?
    var connection: HWConnectionProtocol
    var qrJadeResolver: QRJadeResolver
    
    
    init(testnet: Bool = false) {
        network = testnet ? .testnetSS : .bitcoinSS
        pinServerSession = SessionManager(network.gdkNetwork)
        qrJadeResolver = QRJadeResolverImpl()
        connection = QRJadeConnection(qrJadeResolver: qrJadeResolver)
        device = Jade(gdkRequestDelegate: self, connection: connection)
    }

    func handshakeInit(bcur: BcurDecodedData) async throws -> BcurEncodedData {
        guard bcur.urType == "jade-pin" else {
            throw HWError.Abort("Invalid message")
        }
        guard let id = bcur.res?["id"] as? String, id == "qrauth" else {
            throw HWError.Abort("Invalid message")
        }
        let qrauth = bcur.res?["result"] as? [String: Any]
        let httpRequest = qrauth?["http_request"] as? [String: Any]
        let httpRequestParams = httpRequest?["params"] as? [String: Any]
        let httpRequestMethod = httpRequest?["on-reply"] as? String
        let httpResponse = await self.httpRequest(params: httpRequestParams ?? [:])
        if let error = httpResponse?["error"] as? String {
            throw HWError.Abort(error)
        }
        guard let httpResponseBody = httpResponse?["body"] as? [String: Any] else {
            throw HWError.Abort("Invalid response")
        }
        let package = [
            "id": "qrauth",
            "method": httpRequestMethod as Any,
            "params": httpResponseBody] as [String: Any]
        guard let response = try? CBOR.encodeMap(package) else {
            throw HWError.Abort("Invalid response")
        }
        let params = BcurEncodeParams(urType: "jade-pin", data: response.hex)
        guard let res = try await device?.gdkRequestDelegate?.bcurEncode(params: params) as? BcurEncodedData else {
            throw HWError.Abort("Invalid response")   
        }
        return res
    }
}
extension QRJadeManager: JadeGdkRequest {
    func bcurEncode(params: Any) async throws -> Any {
        guard let params = params as? BcurEncodeParams else {
            throw GaError.GenericError("Invalid bcur")
        }
        let res = try await pinServerSession.bcurEncode(params: params)
        guard let res = res else {
            throw GaError.GenericError("Invalid bcur")
        }
        return res
    }
    
    func httpRequest(params: [String : Any]) async -> [String : Any]? {
        if !pinServerSession.connected {
            try? await pinServerSession.connect()
        }
        return pinServerSession.httpRequest(params: params)
    }
    
    func urlValidation(urls: [String]) async -> Bool {
        fatalError()
    }
    
    func bcurEncode(params: gdk.BcurEncodeParams) async throws -> gdk.BcurEncodedData {
        let res = try await pinServerSession.bcurEncode(params: params)
        guard let res = res else {
            throw GaError.GenericError("Invalid bcur")
        }
        return res
    }
    
    func validateTor(urls: [String]) async -> Bool {
        return true
    }
}
