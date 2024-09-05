import Foundation
import gdk
import greenaddress
import core
import BreezSDK
import lightning

class SendAddressInputViewModel {
    var input: String?
    var preferredAccount: WalletItem?
    var createTx: CreateTx?
    var txType: TxType?

    var wm: WalletManager? { WalletManager.current }
    var settings: Settings? { wm?.prominentSession?.settings }
    var lightningSession: LightningSessionManager? { wm?.lightningSession }

    var bitcoinSinglesigSession: SessionManager? { wm?.bitcoinSinglesigSession }
    var liquidSinglesigSession: SessionManager? { wm?.liquidSinglesigSession }
    var bitcoinMultisigSession: SessionManager? { wm?.bitcoinMultisigSession }
    var liquidMultisigSession: SessionManager? { wm?.liquidMultisigSession }

    var bitcoinSubaccountsWithFunds: [WalletItem] { wm?.bitcoinSubaccountsWithFunds ?? [] }
    var liquidSubaccountsWithFunds: [WalletItem] {
        if let assetId = createTx?.assetId, createTx?.bip21 ?? false {
            return wm?.liquidSubaccountsWithAssetIdFunds(assetId: assetId) ?? []
        } else {
            return wm?.liquidSubaccountsWithFunds ?? []
        }
    }

    var bitcoinSubaccounts: [WalletItem] { wm?.bitcoinSubaccounts ?? [] }
    var liquidSubaccounts: [WalletItem] { wm?.liquidSubaccounts ?? [] }
    var lightningSubaccount: WalletItem? { wm?.lightningSubaccount }

    var isBip21Bitcoin: Bool { (input ?? "").starts(with: "bitcoin:") }
    var isBip21Liquid: Bool { (input ?? "").starts(with: "liquidnetwork:") }
    var isBip21Lightning: Bool { (input ?? "").starts(with: "lightning:") }

    init(input: String? = nil, preferredAccount: WalletItem? = nil, createTx: CreateTx? = nil, txType: TxType? = nil) {
        self.input = input
        self.preferredAccount = preferredAccount
        self.createTx = createTx
        self.txType = txType
    }

    private func parseLightning() async throws -> CreateTx? {
        guard let input = input else { return nil }
        let res = try? await lightningSession?.parseTxInput(input, satoshi: nil, assetId: nil, network: lightningSession?.networkType)
        if res?.isValid ?? false {
            var addressee = res?.addressees.first
            let anyAmounts = addressee?.satoshi ?? 0 == 0
            if anyAmounts == true {
                addressee?.satoshi = nil
            }
            let lightningType = lightningSession?.lightBridge?.parseBoltOrLNUrl(input: input)
            let txType: TxType = { switch lightningType {
                case .bolt11(_): return .bolt11
                default: return .lnurl
            }}()
            return CreateTx(addressee: addressee, subaccount: wm?.lightningSubaccount, error: res?.errors.first, anyAmounts: anyAmounts, lightningType: lightningType, txType: txType)
        } else {
            throw TransactionError.invalid(localizedDescription: res?.errors.first ?? "id_operation_failure")
        }
    }

    private func parsePrivatekey() async throws -> CreateTx?  {
        guard let account = preferredAccount, let input = self.input else {
            throw TransactionError.invalid(localizedDescription: "Invalid input")
        }
        return CreateTx(subaccount: account, privateKey: input, txType: .sweep)
    }

    private func parseGdk(for session: SessionManager, input: String) async throws -> CreateTx? {
        guard let prominentSession = wm?.prominentSession else {
            throw TransactionError.invalid(localizedDescription: "Invalid session")
        }
        let feeAsset = session.gdkNetwork.getFeeAsset()
        let res = try await prominentSession.parseTxInput(input, satoshi: nil, assetId: feeAsset, network: session.networkType)
        if res.isValid {
            var addressee = res.addressees.first
            addressee?.bip21 = isBip21Bitcoin || isBip21Liquid
            if let amount = addressee?.bip21Params?.amount,
                let assetId = addressee?.assetId {
                addressee?.satoshi = Balance.from(amount, assetId: assetId, denomination: .BTC)?.satoshi
            }
            return CreateTx(addressee: addressee, txType: .transaction)
        } else if let error = res.errors.first {
            if "id_no_amount_specified" == error {
                var addressee = res.addressees.first
                addressee?.bip21 = isBip21Bitcoin || isBip21Liquid
                return CreateTx(addressee: addressee, txType: .transaction)
            }
            if !isBip21Liquid && "id_invalid_asset_id" == error {
                var addressee = res.addressees.first
                addressee?.bip21 = isBip21Bitcoin || isBip21Liquid
                return CreateTx(addressee: addressee, txType: .transaction)
            }
            throw TransactionError.invalid(localizedDescription: error)
        }
        return nil
    }

    private func parseGdkBitcoin() async throws -> CreateTx? {
        if let session = bitcoinSinglesigSession ?? bitcoinMultisigSession, let input = self.input {
            return try await parseGdk(for: session, input: input)
        }
        return nil
    }

    private func parseGdkLiquid() async throws -> CreateTx? {
        if let session = liquidSinglesigSession ?? liquidMultisigSession, let input = self.input {
            return try await parseGdk(for: session, input: input)
        }
        return nil
    }

    public func loadSubaccountBalance() async throws {
        let subaccountsWithoutBalance = wm?.subaccounts.filter { $0.satoshi == nil}
        _ = try await wm?.balances(subaccounts: subaccountsWithoutBalance ?? [])
    }

    public func parse() async throws {
        if txType == .sweep {
            createTx = try await parsePrivatekey()
            return
        }
        do {
            if let res = try await parseGdkBitcoin() {
                createTx = res
                return
            }
        } catch {
            if isBip21Bitcoin {
                throw error
            }
        }
        do {
            if let res = try await parseGdkLiquid() {
                createTx = res
                return
            }
        } catch {
            if isBip21Liquid {
                throw error
            }
        }
        do {
            if let res = try await parseLightning() {
                createTx = res
                return
            }
        } catch {
            if isBip21Lightning {
                throw error
            }
        }
        throw TransactionError.invalid(localizedDescription: "id_invalid_address".localized)
    }

    func lightningTransaction() async -> Transaction? {
        var tx = Transaction([:], subaccount: lightningSubaccount?.hashValue)
        if let addressee = createTx?.addressee {
            tx.addressees = [addressee]
        }
        var created = try? await lightningSession?.createTransaction(tx: tx)
        created?.subaccount = lightningSubaccount?.hashValue
        return created
    }

    func sendTxConfirmViewModel() async -> SendTxConfirmViewModel {
        SendTxConfirmViewModel(
            transaction: await lightningTransaction(),
            subaccount: lightningSubaccount,
            denominationType: settings?.denomination ?? .Sats,
            isFiat: false,
            txType: createTx?.txType ?? .transaction, 
            txAddress: nil)
    }

    func accountAssetViewModel() -> AccountAssetViewModel {
        let isBitcoin = createTx?.isBitcoin ?? true
        return AccountAssetViewModel(
            accounts: isBitcoin ? bitcoinSubaccountsWithFunds : liquidSubaccountsWithFunds,
            createTx: createTx)
    }
}
