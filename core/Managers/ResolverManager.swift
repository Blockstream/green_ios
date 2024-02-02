import Foundation
import UIKit
import gdk
import greenaddress
import hw

public class ResolverManager {
    
    public let resolver: GDKResolver
    public let session: SessionManager?
    
    public init(
        _ factor: TwoFactorCall?,
        network: NetworkSecurityCase,
        connected: @escaping() -> Bool = { true },
        hwDevice: HWProtocol?,
        session: SessionManager? = nil,
        popupResolver: PopupResolverDelegate? = nil,
        hwInterfaceDelegate: HwInterfaceResolver? = nil,
        bcurResolver: BcurResolver? = nil) {
        self.session = session
        resolver = GDKResolver(
            factor,
            gdkSession: session?.session,
            popupDelegate: popupResolver,
            hwDelegate: HWResolver(),
            hwInterfaceDelegate: hwInterfaceDelegate,
            bcurDelegate: bcurResolver,
            hwDevice: hwDevice,
            network: network,
            connected: connected
        )
    }

    public func run() async throws -> [String: Any]? {
        try await resolver.resolve()
    }
}
