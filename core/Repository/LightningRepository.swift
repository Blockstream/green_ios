import Foundation
import lightning

public class LightningRepository {

    public static let shared = LightningRepository()

    public func get(for id: String) -> LightningCredentials? {
        return try? AuthenticationTypeHandler
            .getGreenlightCredentials(for: id)
    }

    public func add(for id: String, credentials: LightningCredentials) {
        try? AuthenticationTypeHandler
            .setGreenlightCredentials(certificate: credentials, for: id)
    }

    public func upsert(for id: String, credentials: LightningCredentials) {
        if get(for: id) != nil {
            remove(for: id)
        }
        add(for: id, credentials: credentials)
    }

    public func remove(for id: String) {
        _ = AuthenticationTypeHandler.removeAuth(method: .AuthCertGreenlight, for: id)
    }
}
