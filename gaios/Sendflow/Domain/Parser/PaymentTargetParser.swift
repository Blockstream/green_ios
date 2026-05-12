import LiquidWalletKit
import Foundation
@preconcurrency import core
import gdk
import greenaddress
import GreenlightSDK

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
        let payment = try LiquidWalletKit.Payment(s: text)
        return try await mapPayment(payment, originalText: text)
    }

    // Resolve a BIP-353 input (e.g. ₿user@domain.tld) via DNS and map the
    // returned payment into our PaymentTarget. The caller passes the already
    // parsed `LiquidWalletKit.Payment` (built once in `mapPayment` and carried
    // on `PaymentTarget.bip353`) so we never re-parse the input here. A second
    // hop of BIP-353 is rejected to avoid infinite recursion against malicious
    // DNS records.
    nonisolated func resolveBip353(_ text: String, payment: LiquidWalletKit.Payment) async throws -> PaymentTarget {
        do {
            let resolved = try payment.resolveBip353()
            if resolved.kind() == .bip353 {
                throw SendFlowError.generic("BIP353 resolved to another BIP353; aborting")
            }
            return try await mapPayment(resolved, originalText: text)
        } catch let error as LwkError {
            throw SendFlowError.lwkError(error)
        } catch let error as SendFlowError {
            throw error
        } catch {
            throw SendFlowError.generic(error.description())
        }
    }

    // Shared payment-kind switch used both for initial parse and for the
    // post-resolution mapping after a BIP-353 DNS lookup.
    nonisolated func mapPayment(_ payment: LiquidWalletKit.Payment, originalText: String) async throws -> PaymentTarget {
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
                let currentTimestamp = Int(Date().timeIntervalSince1970)
                let isExpired = lightningInvoice.expiryTime() + lightningInvoice.timestamp() <= currentTimestamp
                if isExpired {
                    throw SendFlowError.generic("id_invoice_expired")
                }
                let paymentHash = lightningInvoice.paymentHash().fromHex()
                let lightningSession = WalletManager.current?.lightningSession
                if let lightningSession, let paymentHash {
                    let isPaidInvoice = try? await lightningSession.isPaidInvoice(paymentHash: paymentHash)
                    if isPaidInvoice ?? false {
                        throw SendFlowError.generic("Invoice already paid")
                    }
                }
                let swapIdsByInvoice = try await BoltzController.shared.fetchSwaps(xpubHashId: mainAccount.xpubHashId ?? "", invoice: lightningInvoice.description, swapType: .Submarine)
                let swapsByInvoice = try await BoltzController.shared.gets(with: swapIdsByInvoice)
                if !swapsByInvoice.filter({ $0.txHash != nil }).isEmpty {
                    throw SendFlowError.generic("Invoice already paid")
                }
                return .lightningInvoice(lightningInvoice)
            }
        case .lightningOffer:
            if let offer = payment.lightningOffer() {
                let lightningPayment = try LightningPayment(s: offer)
                return .lightningOffer(offer, lightningPayment)
            }
        case .lnUrl:
            if let lnurl = payment.lnurl() {
                return .lnUrl(lnurl, payment)
            }
            return .lnUrl(originalText, payment)
        case .bip353:
            // Carry both the raw ₿-prefixed input (for the review screen) and
            // the already-parsed `Payment` so the routing layer can call
            // `resolveBip353` directly without re-parsing. LWK strips the ₿ in
            // `payment.bip353()`, so we cannot reconstruct the kind .bip353
            // payment by re-parsing `payment.bip353()` later: it would be
            // reclassified as .lnUrl.
            return .bip353(originalText, payment)
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
