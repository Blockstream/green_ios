import Foundation
import UIKit

import greenaddress
import hw

public class ResolverManager {

    public let resolver: GDKResolver
    public let session: SessionManager?

    public init(
        _ factor: TwoFactorCall?,
        network: NetworkId,
        connected: @escaping () -> Bool = { true },
        hwDevice: HWProtocol?,
        session: SessionManager? = nil,
        popupResolver: PopupResolverDelegate? = nil,
        hwResolver: HwResolverDelegate? = nil,
        hwInterfaceDelegate: HwInterfaceResolver? = nil,
        bcurResolver: BcurResolver? = nil,
        enableLogs: Bool = true) {
        self.session = session
        resolver = GDKResolver(
            factor,
            gdkSession: session?.session,
            popupDelegate: popupResolver,
            hwDelegate: hwResolver,
            hwInterfaceDelegate: hwInterfaceDelegate,
            bcurDelegate: bcurResolver,
            hwDevice: hwDevice,
            network: network,
            enableLogs: enableLogs,
            connected: connected
        )
    }

    public func run() async throws -> [String: Any]? {
        try await resolver.resolve()
    }
}
