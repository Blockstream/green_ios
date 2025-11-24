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

class QRJadeManager: JadeManager {

    var qrJadeResolver = QRJadeResolverImpl()

    init(network: NetworkSecurityCase) {
        let connection = QRJadeConnection(qrJadeResolver: qrJadeResolver)
        super.init(connection: connection)
    }

    func qrauth(bcur: BcurDecodedData) async throws -> BcurEncodedData {
        guard bcur.urType == "jade-pin" else {
            throw HWError.Abort("Invalid message")
        }
        guard let id = bcur.res?["id"] as? String, id == "qrauth" else {
            throw HWError.Abort("Invalid message")
        }
        let qrauth = bcur.res?["result"] as? [String: Any]
        let httpRequest = qrauth?["http_request"] as? [String: Any]
        //let httpRequestParams = httpRequest?["params"] as? [String: Any]
        let onReply = httpRequest?["on-reply"] as? String
        guard let httpRequest = httpRequest else {
            throw HWError.Abort("Invalid response")
        }
        let httpResponse = try await jade.makeHttpRequest(httpRequest)
        let package = [
            "id": "qrauth",
            "method": onReply as Any,
            "params": httpResponse] as [String: Any]
        guard let response = try? CBOR.encodeMap(package) else {
            throw HWError.Abort("Invalid response")
        }
        let params = BcurEncodeParams(urType: "jade-pin", data: response.hex)
        guard let res = try await jade.gdkRequestDelegate?.bcurEncode(params: params) as? BcurEncodedData else {
            throw HWError.Abort("Invalid response")
        }
        return res
    }
}
