import Foundation
import core
import gdk
import lightning
import greenaddress
import LiquidWalletKit

@MainActor
class LNInvoiceViewModel: ObservableObject {
    var wm: WalletManager { WalletManager.current! }
    let walletDataModel: WalletDataModel
    var lightningReceivePayment: LightningReceivePayment?
    var bolt11: String?
    var satoshi: Int64
    var description: String
    var lwkInvoice: InvoiceResponse?
    var account: WalletItem
    var type: ReceiveType
    var inputDenomination: gdk.DenominationType = .Sats
    var listeningTask: Task<Void, Never>?
    var onInvoicePaid: (() -> Void)?

    init(satoshi: Int64,
         description: String = "",
         account: WalletItem,
         walletDataModel: WalletDataModel,
         type: ReceiveType,
         inputDenomination: DenominationType,
         lightningReceivePayment: LightningReceivePayment?,
         lwkInvoice: InvoiceResponse?,
         bolt11: String
    ) {
        self.satoshi = satoshi
        self.description = description
        self.account = account
        self.walletDataModel = walletDataModel
        self.type = type
        self.inputDenomination = inputDenomination
        self.lightningReceivePayment = lightningReceivePayment
        self.lwkInvoice = lwkInvoice
        self.bolt11 = bolt11
    }

    deinit {
        listeningTask?.cancel()
    }

    func listenToEvents() {
        // Cancel any existing task just in case it's called twice
        listeningTask?.cancel()

        listeningTask = Task { [weak self] in
            // Safely fetch the async stream from the actor
            let eventStream = await self?.walletDataModel.events()
            guard let eventStream else { return }

            for await event in eventStream {
                // Ensure the ViewModel is still alive
                guard let self = self else { return }

                // Translate the low-level EventNotificationTypes into UI Actions
                switch event {
                case .invoicePaid(let details):
                    if details.bolt11.lowercased() == bolt11?.lowercased() {
                        onInvoicePaid?()
                    }
                default:
                    break
                }
            }
        }
    }

    func expiryText() -> String {
        let payment = try? LiquidWalletKit.Payment(s: bolt11 ?? "")
        let invoice = payment?.lightningInvoice()
        let expired = (invoice?.expiryTime() ?? 0) + (invoice?.timestamp() ?? 0)
        let date = Date(timeIntervalSince1970: TimeInterval(expired))
        let df = DateFormatter()
        df.dateFormat = "d MMMM yyyy 'at' h:mm a"
        return "\("Expires".localized) \(df.string(from: date))"
    }
    var fundingFee: UInt64 {
        if let lightningReceivePayment {
            return lightningReceivePayment.openingFeeSatoshi
        }
        return 0
    }
    var fundingFeeText: String {
        if let balance = Balance.fromSatoshi(fundingFee, assetId: "btc") {
            let (value, denom) = balance.toDenom(inputDenomination)
            return "≈ \(value) \(denom)"
        }
        return ""
    }
    var fundingFeeFiatText: String {
        if let balance = Balance.fromSatoshi(fundingFee, assetId: "btc") {
            let (fiat, currency) = balance.toFiat()
            return "≈ \(fiat) \(currency)"
        }
        return ""
    }
    var amountAndFeeText: (String, String) {
        switch type {
        case .address:
            break
        case .bolt11:
            if let lightningReceivePayment {
                let amountSatoshi = lightningReceivePayment.invoice.amountSatoshi ?? 0
                let fee = lightningReceivePayment.openingFeeSatoshi
                let amount = amountSatoshi > fee ? Int64(amountSatoshi - fee) : 0
                if let balance = Balance.fromSatoshi(amount, assetId: "btc") {
                    let (value, denom) = balance.toDenom(inputDenomination)
                    let (fiat, currency) = balance.toFiat()
                    return ("\(value) \(denom)", "≈ \(fiat) \(currency)")
                }
            }
        case .lwkSwap:
            let claimFee = Int64(23)
            let fee = claimFee + Int64((try? self.lwkInvoice?.fee()) ?? 0)
            if satoshi - fee >= 0 {
                if let balance = Balance.fromSatoshi(Int64(satoshi - fee), assetId: "btc") {
                    let (value, denom) = balance.toDenom(inputDenomination)
                    let (fiat, currency) = balance.toFiat()
                    return ("\(value) \(denom)", "≈ \(fiat) \(currency)")
                }
            }
        }
        return ("", "")
    }
    func startMonitoring() {
        Task { [weak self] in
            guard let self = self, let invoice = lwkInvoice else { return }
            if let persistentId = try? await BoltzController.shared.fetchID(byId: invoice.swapId()) {
                await self.wm.swapMonitor?.monitorSwap(id: persistentId)
            }
        }
    }
}
