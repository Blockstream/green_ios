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
        case .ReverseSwapInProgress(let message):
            return message
        case .ServiceConnectivity(let message):
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
        }
    }
}
