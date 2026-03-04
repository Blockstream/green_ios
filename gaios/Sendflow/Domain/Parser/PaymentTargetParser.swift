import LiquidWalletKit
import Foundation
@preconcurrency import core
import gdk
import greenaddress

struct PaymentTargetParser: Sendable {
    public let mainAccount: Account

    nonisolated func parse(_ text: String) async throws -> PaymentTarget {
        do {
            return try await parseLwk(text)
        } catch SendFlowError.invalidPaymentTarget {
            if await isPsbt(text) {
                return .psbt(text)
            } else if await isPset(text) {
                return .pset(text)
            } else if isPrivateKey(text) {
                return .privateKey(text)
            }
            throw SendFlowError.invalidPaymentTarget
        } catch let error as LwkError {
            throw SendFlowError.lwkError(error)
        } catch {
            throw SendFlowError.generic(error.description())
        }
    }
    nonisolated func isPsbt(_ text: String) async -> Bool {
        let wm = WalletManager.current
        let session = wm?.bitcoinSinglesigSession ?? wm?.bitcoinMultisigSession
        let params = PsbtGetDetailParams(psbt: text, utxos: [:])
        let tx = try? await session?.psbtGetDetails(params: params)
        return tx != nil
    }
    nonisolated func isPset(_ text: String) async -> Bool {
        let wm = WalletManager.current
        let session = wm?.liquidSinglesigSession ?? wm?.liquidMultisigSession
        let params = PsbtGetDetailParams(psbt: text, utxos: [:])
        let tx = try? await session?.psbtGetDetails(params: params)
        return tx != nil
    }
    func isPrivateKey(_ text: String) -> Bool {
        ["xpub", "zpub", "upub", "ypub", "vpub"].contains { text.starts(with: $0) }
    }

    nonisolated func parseLwk(_ text: String) async throws -> PaymentTarget {
        let payment = try Payment(s: text)
        switch payment.kind() {
        case .bitcoinAddress:
            if let bitcoinAddress = payment.bitcoinAddress() {
                return .bitcoinAddress(bitcoinAddress)
            }
        case .liquidAddress:
            if let liquidAddress = payment.liquidAddress() {
                return .liquidAddress(liquidAddress)
            }
        case .lightningInvoice:
            if let lightningInvoice = payment.lightningInvoice() {
                if lightningInvoice.amountMilliSatoshis() == nil {
                    throw SendFlowError.generic("Invoice without amount not supported. Paste an invoice with an amount")
                }
                let currentTimestamp = Int(Date().timeIntervalSince1970)
                let isExpired = lightningInvoice.expiryTime() + lightningInvoice.timestamp() <= currentTimestamp
                if isExpired {
                    throw SendFlowError.generic("Invoice expired")
                }
                let swapIdsByInvoice = try await BoltzController.shared.fetchSwaps(xpubHashId: mainAccount.xpubHashId ?? "", invoice: lightningInvoice.description, swapType: .Submarine)
                let swapsByInvoice = try await BoltzController.shared.gets(with: swapIdsByInvoice)
                if !swapsByInvoice.filter({ $0.txHash != nil }).isEmpty {
                    throw SendFlowError.generic("Invoice already paid")
                }
                return .lightningInvoice(lightningInvoice)
            }
        case .lightningOffer:
            throw SendFlowError.generic("Lightning offer not supported. Paste an invoice with an amount")
        case .lnUrl:
            throw SendFlowError.generic("LNURL not supported. Paste an invoice with an amount")
        case .bip353:
            throw SendFlowError.generic("DNS Payment Instructions not supported")
        case .bip21:
            if let bip21 = payment.bip21() {
                return .bip21(bip21)
            }
        case .bip321:
            throw SendFlowError.generic("Bip321 Payment Instructions not supported")
        case .liquidBip21:
            if let liquidBip21 = payment.liquidBip21() {
                return .liquidBip21(liquidBip21)
            }
        }
        throw SendFlowError.invalidPaymentTarget
    }
}
