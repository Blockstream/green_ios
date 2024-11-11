import Foundation

enum MeldTransactionType: String {
    case BUY = "BUY"
    case SELL = "SELL"
}
struct Meld {

    private static let MELD_PRODUCTION = "https://meldcrypto.com"
    private static let MELD_SANDBOX = "https://sb.meldcrypto.com"

    private static let MELD_PRODUCTION_KEY = "WXDhJPMkahPCQ9AjtjS4Mi:49txEyv53WtUvXfVg1FNYvQdzWJc"
    private static let MELD_DEVELOPMENT_KEY = "WQ59eghSwdJxyfaKbk87Cm:D2J97iJX5XjutTot6PAcxNnt4NTuCSWaH"

    let isSandboxEnvironment: Bool

    var meldUrl: String {
        isSandboxEnvironment ? Meld.MELD_SANDBOX : Meld.MELD_PRODUCTION
    }
    var meldKey: String {
        isSandboxEnvironment ? Meld.MELD_DEVELOPMENT_KEY : Meld.MELD_PRODUCTION_KEY
    }

    func buyUrl(
        walletAddressLocked: String,
        destinationCurrencyCodeLocked: String,
        sourceAmount: String,
        sourceCurrencyCode: String) -> String {
            return "\(meldUrl)/?publicKey=\(meldKey)&walletAddressLocked=\(walletAddressLocked)&destinationCurrencyCodeLocked=\(destinationCurrencyCodeLocked)&sourceAmount=\(sourceAmount)&sourceCurrencyCode=\(sourceCurrencyCode)&transactionType=\(MeldTransactionType.BUY.rawValue)"
    }

    func sellUrl(
        walletAddressLocked: String,
        destinationCurrencyCodeLocked: String) -> String {
            return "\(meldUrl)/?publicKey=\(meldKey)&destinationCurrencyCodeLocked=\(destinationCurrencyCodeLocked)&transactionType=\(MeldTransactionType.SELL.rawValue)"
    }
}
