import LiquidWalletKit

public enum SwapType: Int16, Sendable {
    case submarineSwap
    case reverseSwap
    case chainSwap
}

public enum SwapResponse {
    case submarine(PreparePayResponse)
    case reverseSubmarine(InvoiceResponse)
    case chain(LockupResponse)

    func swapId() throws -> String {
        switch self {
        case .submarine(let preparePayResponse):
            try preparePayResponse.swapId()
        case .reverseSubmarine(let invoiceResponse):
            try invoiceResponse.swapId()
        case .chain(let lockupResponse):
            try lockupResponse.swapId()
        }
    }
    func serialize() throws -> String {
        switch self {
        case .submarine(let preparePayResponse):
            try preparePayResponse.serialize()
        case .reverseSubmarine(let invoiceResponse):
            try invoiceResponse.serialize()
        case .chain(let lockupResponse):
            try lockupResponse.serialize()
        }
    }
    func advance() throws -> PaymentState {
        switch self {
        case .submarine(let preparePayResponse):
            try preparePayResponse.advance()
        case .reverseSubmarine(let invoiceResponse):
            try invoiceResponse.advance()
        case .chain(let lockupResponse):
            try lockupResponse.advance()
        }
    }
}

