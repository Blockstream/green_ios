import Foundation
import LiquidWalletKit
import core
import gdk
import greenaddress
import lightning

actor TransactionBuilder {
    // Resolve an LNURL Payment to a LightningPayment by fetching the bolt11
    // invoice for the requested amount. Network-bound and amount-dependent,
    // so callers must run it once they have a final user amount.
    static func resolveLnurlPayment(_ payment: LiquidWalletKit.Payment, amount: UInt64) async throws -> LightningPayment {
        return try await Task.detached(priority: .userInitiated) {
            guard payment.kind() == .lnUrl else {
                throw TransactionError.invalid(localizedDescription: "Invalid LNURL")
            }
            let info = try payment.resolveLnurlInfo()
            let lnurlInvoice = try payment.fetchLnurlInvoice(info: info, amountSats: amount)
            guard let resolved = lnurlInvoice.lightningInvoice()?.description else {
                throw TransactionError.invalid(localizedDescription: "Invalid LNURL invoice")
            }
            return LightningPayment.fromBolt11Invoice(invoice: try Bolt11Invoice(s: resolved))
        }.value
    }


    static func buildTransactionDraft(paymentTarget: PaymentTarget, subaccount: WalletItem?, assetId: String?, lockupResponse: LockupResponse? = nil, swapPayResponse: PreparePayResponse? = nil, swapPosition: SwapPositionState? = nil) -> TransactionDraft {
        switch paymentTarget {
        case .lightningInvoice(let bolt11):
            let satoshi: UInt64? = {
                if let satoshi = bolt11.amountMilliSatoshis() {
                    return satoshi/1000
                }
                return nil
            }()
            return TransactionDraft(
                subaccount: subaccount,
                address: bolt11.description,
                satoshi: satoshi,
                assetId: nil,
                sendAll: nil,
                paymentTarget: paymentTarget,
                lockupResponse: lockupResponse,
                swapPosition: swapPosition,
                swapPayResponse: swapPayResponse)
        case .bip21(let bip21):
            return TransactionDraft(
                subaccount: subaccount,
                address: bip21.address().description,
                satoshi: bip21.amount(),
                assetId: nil,
                sendAll: nil,
                paymentTarget: paymentTarget,
                lockupResponse: lockupResponse,
                swapPosition: swapPosition,
                swapPayResponse: swapPayResponse)
        case .liquidBip21(let liquidBip21):
            return TransactionDraft(
                subaccount: subaccount,
                address: liquidBip21.address.description,
                satoshi: liquidBip21.satoshi,
                assetId: liquidBip21.asset.description,
                sendAll: false,
                paymentTarget: paymentTarget,
                lockupResponse: lockupResponse,
                swapPosition: swapPosition,
                swapPayResponse: swapPayResponse)
        case .bitcoinAddress(let address):
            return TransactionDraft(
                subaccount: subaccount,
                address: address.description,
                satoshi: nil,
                assetId: nil,
                sendAll: false,
                paymentTarget: paymentTarget,
                lockupResponse: lockupResponse,
                swapPosition: swapPosition,
                swapPayResponse: swapPayResponse)
        case .liquidAddress(let address):
            return TransactionDraft(
                subaccount: subaccount,
                address: address.description,
                satoshi: nil,
                assetId: assetId,
                sendAll: false,
                paymentTarget: paymentTarget,
                lockupResponse: lockupResponse,
                swapPosition: swapPosition,
                swapPayResponse: swapPayResponse)
        default:
            return TransactionDraft(
                subaccount: subaccount,
                address: nil,
                satoshi: nil,
                assetId: nil,
                sendAll: false,
                paymentTarget: paymentTarget,
                lockupResponse: lockupResponse,
                swapPosition: swapPosition,
                swapPayResponse: swapPayResponse)
        }
    }
    static func buildGdkTransaction(uri: String, satoshi: Int64, session: SessionManager, subaccount: WalletItem) async throws -> gdk.Transaction {
        return try await Task.detached(priority: .userInitiated) {
            var tx = Transaction([:], subaccountId: subaccount.id)
            tx.feeRate = try await session.getFeeEstimates()?.first ?? session.gdkNetwork.defaultFee
            let unspent = try await session.getUnspentOutputs(GetUnspentOutputsParams(subaccount: subaccount.pointer, numConfs: 0))
            tx.utxos = unspent
            let assetId = session.networkType.gdkNetwork.getFeeAssetOrNull()
            tx.addressees = [Addressee.from(address: uri, satoshi: satoshi, assetId: assetId)]
            tx = try await session.createTransaction(tx: tx)
            return tx
        }.value
    }
    static func sendGdkTransaction(tx: gdk.Transaction, session: SessionManager) async throws -> SendTransactionSuccess {
        return try await Task.detached(priority: .userInitiated) {
            var tx = tx
            if session.networkType.liquid {
                tx = try await session.blindTransaction(tx: tx)
                if let error = tx.error {
                    throw TransactionError.invalid(localizedDescription: error)
                }
            }
            tx = try await session.signTransaction(tx: tx)
            if let error = tx.error {
                throw TransactionError.invalid(localizedDescription: error)
            }
            return try await session.sendTransaction(tx: tx)
        }.value
    }

    // Unified swap-prep path keyed on LightningPayment. Used by BOLT11, BOLT12
    // (after the user amount has been set on the offer) and LNURL (after the
    // bolt11 invoice has been resolved). The DB dedup is keyed on the resolved
    // bolt11 invoice; for BOLT12 offers that don't expose a resolvable invoice
    // yet, dedup is skipped (we still proceed with a fresh preparePay).
    static func buildSwap(lightningPayment: LightningPayment, lwk: LwkSessionManager, subaccount: WalletItem, xpub: String) async throws -> PreparePayResponse {
        return try await Task.detached(priority: .userInitiated) {
            if let invoice = try lightningPayment.bolt11Invoice()?.description {
                let swapIdsByInvoice = try await BoltzController.shared.fetchSwaps(xpubHashId: xpub, invoice: invoice, swapType: .Submarine)
                let swapsByInvoice = try await BoltzController.shared.gets(with: swapIdsByInvoice)
                if !swapsByInvoice.filter({ $0.txHash != nil }).isEmpty {
                    throw TransactionError.invalid(localizedDescription: "Invoice already paid")
                }
                if let swap = swapsByInvoice.filter({ $0.txHash == nil }).first, let data = swap.data {
                    if let pay = try await lwk.restorePreparePay(data: data) {
                        return pay
                    }
                }
            }
            let address = try await subaccount.session?.getReceiveAddress(subaccount: subaccount.pointer)
            guard let address = address?.address else {
                throw TransactionError.invalid(localizedDescription: "Invalid address")
            }
            let refundAddress = try LiquidWalletKit.Address(s: address)
            return try await lwk.preparePay(lightningPayment: lightningPayment, refundAddress: refundAddress)
        }.value
    }

    static func buildSubmarineSwapTransaction(lightningPayment: LightningPayment, lwk: LwkSessionManager, subaccount: WalletItem, xpub: String) async throws -> (PreparePayResponse?, gdk.Transaction) {
        return try await Task.detached(priority: .userInitiated) {
            guard let session = subaccount.session else {
                throw TransactionError.invalid(localizedDescription: "No Lwk session")
            }
            do {
                let swap = try await TransactionBuilder.buildSwap(
                    lightningPayment: lightningPayment,
                    lwk: lwk,
                    subaccount: subaccount,
                    xpub: xpub)
                let satoshi = try swap.uriAmount()
                let tx = try await TransactionBuilder.buildGdkTransaction(
                    uri: try swap.uri(),
                    satoshi: Int64(satoshi),
                    session: session,
                    subaccount: subaccount)
                return (swap, tx)
            } catch {
                switch error as? LwkError {
                case .MagicRoutingHint(let address, let amount, let uri):
                    let tx = try await TransactionBuilder.buildGdkTransaction(
                        uri: uri,
                        satoshi: Int64(amount),
                        session: session,
                        subaccount: subaccount)
                    return (nil, tx)
                default:
                    throw error
                }
            }
        }.value
    }
    static func buildCrossChainSwap(from: WalletItem, to: WalletItem, amount: UInt64, lwk: LwkSessionManager, xpub: String) async throws -> LockupResponse {
        if from.networkType.bitcoin && to.networkType.liquid {
            return try await buildBtcToLbtcSwap(from: from, to: to, amount: amount, lwk: lwk, xpub: xpub)
        } else if from.networkType.liquid && to.networkType.bitcoin {
            return try await buildLbtcToBtcSwap(from: from, to: to, amount: amount, lwk: lwk, xpub: xpub)
        } else {
            throw SendFlowError.failedToBuildTransaction
        }
    }
    static func buildGdkTransaction(lockupResponse: LockupResponse, subaccount: WalletItem, feeRate: UInt64? = nil) async throws ->
    gdk.Transaction {
        
        return try await Task.detached(priority: .userInitiated) {
            guard let session = subaccount.session else {
                throw SendFlowError.invalidSession
            }
            var tx = Transaction([:], subaccountId: subaccount.id)
            if let feeRate {
                tx.feeRate = feeRate
            } else {
                tx.feeRate = try await session.getFeeEstimates()?.first ?? session.gdkNetwork.defaultFee
            }
            let unspent = try await session.getUnspentOutputs(GetUnspentOutputsParams(subaccount: subaccount.pointer, numConfs: 0))
            tx.utxos = unspent
            let assetId = session.networkType.gdkNetwork.getFeeAssetOrNull()
            let address = try lockupResponse.lockupAddress()
            let amount = try lockupResponse.expectedAmount()
            tx.addressees = [Addressee.from(address: address, satoshi: Int64(amount), assetId: assetId)]
            tx = try await session.createTransaction(tx: tx)
            return tx
        }.value
    }

    static func buildLbtcToBtcSwap(from: WalletItem, to: WalletItem, amount: UInt64, lwk: LwkSessionManager, xpub: String) async throws -> LockupResponse {
        return try await Task.detached(priority: .userInitiated) {
            // Get a Liquid refund address
            guard let refundAddress = try await from.session?.getReceiveAddress(subaccount: from.pointer).address else {
                throw SendFlowError.failedToBuildTransaction
            }
            // Ask for the Bitcoin claim address
            guard let claimAddress = try await to.session?.getReceiveAddress(subaccount: to.pointer).address else {
                throw SendFlowError.failedToBuildTransaction
            }
            // Create the swap
            return try await lwk.lbtcToBtc(amount: amount, refundAddress: refundAddress, claimAddress: claimAddress, xpubHashId: xpub)
        }.value
    }
    static func buildBtcToLbtcSwap(from: WalletItem, to: WalletItem, amount: UInt64, lwk: LwkSessionManager, xpub: String) async throws -> LockupResponse {
        return try await Task.detached(priority: .userInitiated) {
            // Get a Bitcoin refund address
            guard let refundAddress = try await from.session?.getReceiveAddress(subaccount: from.pointer).address else {
                throw SendFlowError.failedToBuildTransaction
            }
            // Ask for the Liquid claim address
            guard let claimAddress = try await to.session?.getReceiveAddress(subaccount: to.pointer).address else {
                throw SendFlowError.failedToBuildTransaction
            }
            // Create the swap
            return try await lwk.btcToLbtc(amount: amount, refundAddress: refundAddress, claimAddress: claimAddress, xpubHashId: xpub)
        }.value
    }

    func buildGdkTransaction(psbt: String, subaccount: WalletItem) async throws -> gdk.Transaction {
        return try await Task.detached(priority: .userInitiated) {
            let wallyPsbt = try Wally.psbtFromBase64(psbt)
            let isFinalized = try Wally.psbtIsFinalized(wallyPsbt)
            let isPset = try Wally.psbtIsElements(wallyPsbt)
            if subaccount.networkType.liquid && !isPset {
                throw TransactionError.invalid(localizedDescription: "Select a liquid subaccount for Pset")
            } else if !subaccount.networkType.liquid && isPset {
                throw TransactionError.invalid(localizedDescription: "Select a bitcoin subaccount for Psbt")
            }
            guard let session = subaccount.session else {
                throw TransactionError.invalid(localizedDescription: "Select subaccount")
            }
            var tx = try await session.psbtGetDetails(params: PsbtGetDetailParams(psbt: psbt, utxos: [:]))
            let addressee = tx.transactionOutputs?.map { Addressee.from(address: $0.address ?? "", satoshi: $0.satoshi, assetId: $0.assetId) }
            tx.addressees = addressee ?? []
            tx.subaccountId = subaccount.id
            return tx
        }.value
    }

    static func buildCreateTx(_ tx: TransactionDraft) throws -> CreateTx {
        guard let type = tx.paymentTarget else {
            throw SendFlowError.invalidPaymentTarget
        }
        switch type {
        case .bitcoinAddress(let address):
            return CreateTx(
                addressee: Addressee.from(address: address.description, satoshi: nil, assetId: nil),
                subaccount: tx.subaccount,
                txType: .transaction)
        case .liquidAddress(let address):
            return CreateTx(
                addressee: Addressee.from(address: address.description, satoshi: nil, assetId: tx.assetId ?? address.network().policyAsset()),
                subaccount: tx.subaccount,
                txType: .transaction)
        case .lightningInvoice(let bolt11):
            return CreateTx(txType: .bolt11)
        case .lightningOffer(let offer, _):
            return CreateTx(
                addressee: Addressee.from(address: offer, satoshi: tx.satoshi == nil ? nil : Int64(tx.satoshi ?? 0), assetId: nil, txType: .bolt11),
                subaccount: tx.subaccount,
                anyAmounts: tx.satoshi == nil,
                bolt11: offer.description,
                txType: .bolt11)
        case .lnUrl(let url, _):
            return CreateTx(
                addressee: Addressee.from(address: url, satoshi: nil, assetId: nil),
                subaccount: tx.subaccount,
                anyAmounts: true,
                txType: .lnurl)
        case .bip353(_):
            throw TransactionError.invalid(localizedDescription: "bip353 not supported")
        case .bip21(let bip21):
            var amount: Int64?
            if let bip21Amount = bip21.amount() {
                amount = Int64(bip21Amount)
            }
            return CreateTx(
                addressee: Addressee.from(address: bip21.address().description, satoshi: amount, assetId: nil),
                subaccount: tx.subaccount,
                txType: .transaction)
        case .bip321(_):
            throw TransactionError.invalid(localizedDescription: "bip321 not supported")
        case .liquidBip21(let bip21):
            let satoshi = bip21.satoshi == nil ? nil : Int64(bip21.satoshi ?? 0)
            return CreateTx(
                addressee: Addressee.from(address: bip21.address.description, satoshi: satoshi, assetId: bip21.asset),
                subaccount: tx.subaccount,
                txType: .transaction)
        case .psbt(let text):
            return CreateTx(
                subaccount: tx.subaccount,
                txType: .psbt,
                psbt: text)
        case .pset(let text):
            return CreateTx(
                subaccount: tx.subaccount,
                txType: .psbt,
                psbt: text)
        case .privateKey(let key):
            return CreateTx(
                subaccount: tx.subaccount,
                privateKey: key,
                txType: .sweep)
        }
    }

    static func build(from lightningSubaccount: WalletItem, invoice: Bolt11Invoice, satoshi: UInt64?) async throws -> gdk.Transaction {
        return try await Task.detached(priority: .userInitiated) {
            guard let fallbackSession = lightningSubaccount.session else {
                throw GaError.GenericError("No lightning subaccount session")
            }
            let lightningSession = WalletManager.current?.lightningSession ?? fallbackSession
            let satoshi = invoice.amountMilliSatoshis()?.satoshi ?? satoshi
            let addressee = Addressee.from(
                address: invoice.description,
                satoshi: satoshi != nil ? Int64(satoshi ?? 0) : nil,
                assetId: nil,
                isGreedy: false
            )
            var tx = Transaction([:], subaccountId: lightningSubaccount.id)
            tx.addressees = [addressee]
            tx.paymentHash = invoice.paymentHash()
            tx.invoice = invoice.description
            tx.memo = invoice.invoiceDescription().localized
            tx.anyAmouts = satoshi == nil
            tx.fee = 0
            var created = try await lightningSession.createTransaction(tx: tx)
            created.subaccountId = lightningSubaccount.id
            return created
        }.value
    }

    static func build(from lightningSubaccount: WalletItem, lnurl: String, payment: LiquidWalletKit.Payment, satoshi: UInt64) async throws -> gdk.Transaction {
        return try await Task.detached(priority: .userInitiated) {
            guard payment.kind() == .lnUrl else {
                throw TransactionError.invalid(localizedDescription: "Invalid LNURL")
            }
            let info = try payment.resolveLnurlInfo()
            let lnurlInvoice = try payment.fetchLnurlInvoice(info: info, amountSats: satoshi)
            guard let resolvedInvoice = lnurlInvoice.lightningInvoice()?.description else {
                throw TransactionError.invalid(localizedDescription: "Invalid LNURL invoice")
            }
            let bolt11 = try Bolt11Invoice(s: resolvedInvoice)
            return try await TransactionBuilder.build(
                from: lightningSubaccount,
                invoice: bolt11,
                satoshi: nil
            )
        }.value
    }
}
