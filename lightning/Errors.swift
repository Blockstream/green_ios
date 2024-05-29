import Foundation
import BreezSDK

extension BreezSDK.SdkError {
    public func description() -> String? {
        switch self {
        case .Generic(let message):
            return message
        case .ServiceConnectivity(let message):
            return message
        }
    }
}

extension BreezSDK.SendOnchainError {
    public  func description() -> String? {
        switch self {
        case .Generic(let message):
            return message
        case .InvalidDestinationAddress(let message):
            return message
        case .PaymentFailed(let message):
            return message
        case .PaymentTimeout(let message):
            return message
        case .ServiceConnectivity(let message):
            return message
        case .OutOfRange(message: let message):
            return message
        }
    }
}
extension BreezSDK.SendPaymentError {
    public func description() -> String? {
        switch self {
        case .AlreadyPaid(let message):
            return message
        case .Generic(let message):
            return message
        case .InvalidAmount(let message):
            return message
        case .InvalidInvoice(let message):
            return message
        case .InvoiceExpired(let message):
            return message
        case .InvalidNetwork(let message):
            return message
        case .PaymentFailed(let message):
            return message
        case .PaymentTimeout(let message):
            return message
        case .RouteNotFound(let message):
            return message
        case .RouteTooExpensive(let message):
            return message
        case .ServiceConnectivity(let message):
            return message
        }
    }
}

extension BreezSDK.ReceiveOnchainError {
    public func description() -> String? {
        switch self {
        case .Generic(let message):
            return message
        case .ServiceConnectivity(let message):
            return message
        case .SwapInProgress(let message):
            return message
        }
    }
}

extension BreezSDK.ConnectError {
    public func description() -> String? {
        switch self {
        case .Generic(message: let message):
            return message
        case .RestoreOnly(message: let message):
            return message
        case .ServiceConnectivity(message: let message):
            return message
        }
    }
}

extension BreezSDK.ReceivePaymentError {
    public func description() -> String? {
        switch self {
        case .Generic(let message):
            return message
        case .InvalidAmount(let message):
            return message
        case .InvalidInvoice(let message):
            return message
        case .InvoiceExpired(let message):
            return message
        case .InvoiceNoDescription(let message):
            return message
        case .InvoicePreimageAlreadyExists(let message):
            return message
        case .ServiceConnectivity(let message):
            return message
        case .InvoiceNoRoutingHints(let message):
            return message
        }
    }
}

extension BreezSDK.LnUrlAuthError {
    public func description() -> String? {
        switch self {
        case .Generic(message: let message):
            return message
        case .InvalidUri(message: let message):
            return message
        case .ServiceConnectivity(message: let message):
            return message
        }
    }
}
extension BreezSDK.LnUrlPayError {
    public func description() -> String? {
        switch self {
        case .AlreadyPaid(message: let message):
            return message
        case .Generic(message: let message):
            return message
        case .InvalidAmount(message: let message):
            return message
        case .InvalidInvoice(message: let message):
            return message
        case .InvalidNetwork(message: let message):
            return message
        case .InvalidUri(message: let message):
            return message
        case .InvoiceExpired(message: let message):
            return message
        case .PaymentFailed(message: let message):
            return message
        case .PaymentTimeout(message: let message):
            return message
        case .RouteNotFound(message: let message):
            return message
        case .RouteTooExpensive(message: let message):
            return message
        case .ServiceConnectivity(message: let message):
            return message
        }
    }
}
