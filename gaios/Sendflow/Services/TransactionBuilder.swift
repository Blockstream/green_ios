import Foundation
import LiquidWalletKit
import core
import gdk
import greenaddress
import lightning
import BreezSDK

actor TransactionBuilder {

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
    
    static func buildGdkTransactionFomBreez(lightningSubaccount: WalletItem, createTx: CreateTx) async throws -> gdk.Transaction {
        return try await Task.detached(priority: .userInitiated) {
            guard let lightningSession = lightningSubaccount.session else {
                throw GaError.GenericError("No lightning session")
            }
            var tx = Transaction([:], subaccountId: lightningSubaccount.id)
            tx.addressees = [createTx.addressee]
            var created = try await lightningSession.createTransaction(tx: tx)
            created.subaccountId = lightningSubaccount.id
            return created
        }.value
    }
    static func buildSwap(invoice: String, lwk: LwkSessionManager, subaccount: WalletItem, xpub: String) async throws -> PreparePayResponse {
        return try await Task.detached(priority: .userInitiated) {
            let existingSwapIds = try await BoltzController.shared.fetchIDs(byXpubHashId: xpub, byInvoice: invoice)
            if let swapId = existingSwapIds.first {
                if let swap = try await BoltzController.shared.get(with: swapId), swap.type == .Submarine, let data = swap.data {
                    guard let pay = try await lwk.restorePreparePay(data: data) else {
                        throw TransactionError.invalid(localizedDescription: "Invalid restored swap")
                    }
                    return pay
                }
            }
            let address = try await subaccount.session?.getReceiveAddress(subaccount: subaccount.pointer)
            guard let address = address?.address else {
                throw TransactionError.invalid(localizedDescription: "Invalid address")
            }
            let refundAddress = try LiquidWalletKit.Address(s: address)
            return try await lwk.preparePay(invoice: invoice, refundAddress: refundAddress)
        }.value
    }

    static func buildSubmarineSwapTransaction(invoice: String, lwk: LwkSessionManager, subaccount: WalletItem, xpub: String) async throws -> (PreparePayResponse?, gdk.Transaction) {
        return try await Task.detached(priority: .userInitiated) {
            guard let session = subaccount.session else {
                throw TransactionError.invalid(localizedDescription: "No Lwk session")
            }
            do {
                let swap = try await TransactionBuilder.buildSwap(
                    invoice: invoice,
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
            return try buildBreezCreateTx(input: bolt11.description, subaccount: tx.subaccount)
        case .lightningOffer(let offer):
            return CreateTx(
                subaccount: tx.subaccount,
                bolt11: offer.description,
                txType: .bolt11)
        case .lnUrl(let url):
            return try buildBreezCreateTx(input: url, subaccount: tx.subaccount)
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

    static func buildBreezCreateTx(input: String, subaccount: WalletItem?) throws -> CreateTx {
        let inputType = try LightningBridge.parseBoltOrLNUrl(input: input)
        switch inputType {
        case .bolt11(let invoice):
            var addr = Addressee.fromLnInvoice(invoice, fallbackAmount: 0)
            let anyAmounts = addr.satoshi ?? 0 == 0
            if anyAmounts == true {
                addr.satoshi = nil
            }
            return CreateTx(addressee: addr, subaccount: subaccount, error: nil, anyAmounts: anyAmounts, lightningType: inputType, txType: .bolt11)
        case .lnUrlPay(let data, let bip353Address):
            var addr = Addressee.fromRequestData(data, input: input, satoshi: nil)
            return CreateTx(addressee: addr, subaccount: subaccount, error: nil, anyAmounts: nil, lightningType: inputType, txType: .lnurl)
        default:
            throw SendFlowError.invalidPaymentTarget
        }
    }
}

