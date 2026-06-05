import Foundation
@preconcurrency import core
@preconcurrency import gdk
import LiquidWalletKit
import greenaddress
@preconcurrency import lightning

actor ReceiveService {
    struct AddressRequest: Sendable {
        let subaccount: WalletItem
        let walletManager: WalletManager
    }

    struct AddressResponse: Sendable {
        let address: gdk.Address?
    }

    struct ReverseSwapInfoRequest: Sendable {
        let walletManager: WalletManager
    }

    struct ReverseSwapInfoResponse: Sendable {
        let info: BoltzReverseSwapInfoLBTC?
    }

    struct LightningInvoiceRequest: Sendable {
        let walletManager: WalletManager
        let satoshi: UInt64
        let description: String
    }

    struct LightningInvoiceResponse: Sendable {
        let payment: LightningReceivePayment?
        let bolt11: String?
    }

    struct ReverseSwapInvoiceRequest: Sendable {
        let subaccount: WalletItem
        let walletManager: WalletManager
        let satoshi: UInt64
        let description: String
    }

    struct ReverseSwapInvoiceResponse: Sendable {
        let invoice: InvoiceResponse?
        let bolt11: String?
    }

    func fetchReverseSwapInfo(_ request: ReverseSwapInfoRequest) async throws -> ReverseSwapInfoResponse {
        let info = try await request.walletManager.lwkSession?.fetchReverseSwapsInfo()
        return ReverseSwapInfoResponse(info: info)
    }

    func buildAddress(_ request: AddressRequest) async throws -> AddressResponse {
        let account = request.subaccount
        let session = request.walletManager.sessions[account.gdkNetwork.network]
        let address = try await session?.getReceiveAddress(subaccount: account.pointer)
        return AddressResponse(address: address)
    }

    func createLightningInvoice(_ request: LightningInvoiceRequest) async throws -> LightningInvoiceResponse {
        let payment = try await request.walletManager.lightningSession?.createInvoice(
            satoshi: request.satoshi,
            description: request.description)
        return LightningInvoiceResponse(payment: payment, bolt11: payment?.invoice.bolt11)
    }

    func createReverseSwapInvoice(_ request: ReverseSwapInvoiceRequest) async throws -> ReverseSwapInvoiceResponse {
        logger.info("BOLTZ getReceiveAddress")
        let address = try await request.subaccount.session?.getReceiveAddress(subaccount: request.subaccount.pointer)
        guard let address = address?.address else {
            throw GaError.GenericError("Invalid address")
        }
        logger.info("BOLTZ invoice")
        let claimAddress = try LiquidWalletKit.Address(s: address)
        let invoice = try await request.walletManager.awaitLwkSession()?.invoice(
            amount: request.satoshi,
            description: request.description,
            claimAddress: claimAddress)
        let bolt11 = try invoice?.bolt11Invoice().description
        logger.info("BOLTZ invoiced")
        return ReverseSwapInvoiceResponse(invoice: invoice, bolt11: bolt11)
    }
}
