import Foundation
import lightning

public class LightningRepository {

    public static let shared = LightningRepository()
    
    public func get(for id: String) -> AppGreenlightCredentials? {
        return try? AuthenticationTypeHandler.getCertLightning(forNetwork: id)
    }

    public func add(for id: String, credentials: AppGreenlightCredentials) {
        try? AuthenticationTypeHandler.addCertLightning(forNetwork: id, credentials: credentials)
    }

    public func upsert(for id: String, credentials: AppGreenlightCredentials) {
        if get(for: id) != nil {
            remove(for: id)
        }
        add(for: id, credentials: credentials)
    }

    public func remove(for id: String) {
        _ = AuthenticationTypeHandler.removeAuth(method: .AuthCertLightning, forNetwork: id)
    }
}
