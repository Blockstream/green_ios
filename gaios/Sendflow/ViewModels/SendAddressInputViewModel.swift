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
    var assetId: String?

    var wm: WalletManager? { WalletManager.current }
    var settings: Settings? { wm?.prominentSession?.settings }
    var lightningSession: LightningSessionManager? { wm?.lightningSession }

    var bitcoinSinglesigSession: SessionManager? { wm?.bitcoinSinglesigSession }
    var liquidSinglesigSession: SessionManager? { wm?.liquidSinglesigSession }
    var bitcoinMultisigSession: SessionManager? { wm?.bitcoinMultisigSession }
    var liquidMultisigSession: SessionManager? { wm?.liquidMultisigSession }

    var bitcoinSubaccountsWithFunds: [WalletItem] { wm?.bitcoinSubaccountsWithFunds ?? [] }
    var liquidSubaccountsWithFunds: [WalletItem] {
        if let assetId = createTx?.assetId {
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
    
    var bitcoinSession: SessionManager? { bitcoinSinglesigSession ?? bitcoinMultisigSession }
    var liquidSession: SessionManager? { liquidSinglesigSession ?? liquidMultisigSession }

    init(input: String? = nil,
         preferredAccount: WalletItem? = nil,
         createTx: CreateTx? = nil,
         txType: TxType? = nil,
         assetId: String? = nil) {
        self.input = input
        self.preferredAccount = preferredAccount
        self.createTx = createTx
        self.txType = txType
        self.assetId = assetId
    }

    private func parseLightning() async throws -> CreateTx? {
        guard let input = input, let lightningSession = lightningSession else {
            return nil
        }
        if let account = preferredAccount, !account.networkType.lightning {
            return nil
        }
        let res = try? await lightningSession.parseTxInput(input, satoshi: nil, assetId: nil, network: lightningSession.networkType)
        if res?.isValid ?? false {
            var addressee = res?.addressees.first
            let anyAmounts = addressee?.satoshi ?? 0 == 0
            if anyAmounts == true {
                addressee?.satoshi = nil
            }
            let lightningType = lightningSession.lightBridge?.parseBoltOrLNUrl(input: input)
            let txType: TxType = { switch lightningType {
                case .bolt11(_): return .bolt11
                default: return .lnurl
            }}()
            return CreateTx(addressee: addressee, subaccount: wm?.lightningSubaccount, error: res?.errors.first, anyAmounts: anyAmounts, lightningType: lightningType, txType: txType)
        } else {
            if isBip21Lightning || preferredAccount?.networkType.lightning ?? false {
                throw TransactionError.invalid(localizedDescription: res?.errors.first ?? "id_invalid_address")
            }
            return nil
        }
    }

    private func parsePrivatekey() async throws -> CreateTx? {
        guard let input = self.input, txType == .sweep else {
            return nil
        }
        if let account = preferredAccount, !account.networkType.bitcoin {
            throw TransactionError.invalid(localizedDescription: "Select a Bitcoin account to sweep")
        }
        let account = preferredAccount ?? bitcoinSubaccounts.first
        return CreateTx(subaccount: account, privateKey: input, txType: .sweep)
    }

    private func parseGdk(for session: SessionManager, input: String) async throws -> CreateTx? {
        let feeAsset = session.gdkNetwork.getFeeAssetOrNull()
        let res = try await wm?.prominentSession?.parseTxInput(input, satoshi: 1_000_000, assetId: feeAsset, network: session.networkType)
        if res?.isValid ?? false {
            var addressee = res?.addressees.first
            addressee?.bip21 = isBip21Bitcoin || isBip21Liquid
            addressee?.satoshi = nil
            if let amount = addressee?.bip21Params?.amount {
                let assetId = addressee?.bip21Params?.assetid ?? session.gdkNetwork.getFeeAsset()
                addressee?.satoshi = Balance.from(amount, assetId: assetId, denomination: .BTC)?.satoshi
            }
            let assetId = addressee?.bip21Params?.assetid ?? addressee?.assetId
            if let assetId = assetId, assetId != "btc" {
                addressee?.assetId = assetId
            } else {
                addressee?.assetId = session.gdkNetwork.getFeeAssetOrNull()
            }
            return CreateTx(addressee: addressee, txType: .transaction)
        } else {
            if session.networkType.liquid && isBip21Liquid {
                throw TransactionError.invalid(localizedDescription: "id_invalid_address")
            } else if session.networkType.bitcoin && isBip21Bitcoin {
                throw TransactionError.invalid(localizedDescription: "id_invalid_address")
            }
            return nil
        }
    }

    private func parseGdkBitcoin() async throws -> CreateTx? {
        guard let session = preferredAccount?.session ?? bitcoinSession,
              let input = self.input, session.networkType.bitcoin else {
            return nil
        }
        let res = try await parseGdk(for: session, input: input)
        if let preferredAccount = preferredAccount, !preferredAccount.networkType.bitcoin && res != nil {
            throw TransactionError.invalid(localizedDescription: "Select a Bitcoin account")
        }
        return res
    }

    private func parseGdkLiquid() async throws -> CreateTx? {
        guard let session = preferredAccount?.session ?? liquidSession,
                let input = self.input, session.networkType.liquid else {
            return nil
        }
        guard let res = try await parseGdk(for: session, input: input) else {
            return nil
        }
        if let preferredAccount = preferredAccount, !preferredAccount.networkType.liquid {
            throw TransactionError.invalid(localizedDescription: "Select a Liquid account")
        }
        if let assetId = assetId, assetId != res.assetId {
            throw TransactionError.invalid(localizedDescription: "Asset mismatch")
        }
        return res
    }

    private func parsePsbt(for session: SessionManager, input: String) async throws -> CreateTx? {
        let tx = try await wm?.prominentSession?.psbtGetDetails(params: PsbtGetDetailParams(psbt:  input, utxos: [:]))
        return CreateTx(txType: .psbt, psbt: input)
    }

    private func parsePsbtBitcoin() async throws -> CreateTx? {
        if let session = bitcoinSinglesigSession ?? bitcoinMultisigSession, let input = self.input {
            return try await parsePsbt(for: session, input: input)
        }
        return nil
    }
    private func parsePsbtLiquid() async throws -> CreateTx? {
        if let session = liquidSinglesigSession ?? liquidMultisigSession, let input = self.input {
            return try await parsePsbt(for: session, input: input)
        }
        return nil
    }

    public func loadSubaccountBalance() async throws {
        let subaccountsWithoutBalance = wm?.subaccounts.filter { $0.satoshi == nil}
        _ = try await wm?.balances(subaccounts: subaccountsWithoutBalance ?? [])
    }

    public func parse() async throws {
        if let res = try await parsePrivatekey() {
            createTx = res
            return
        }
        if let res = try await parseGdkBitcoin() {
            createTx = res
            return
        }
        if let res = try await parseGdkLiquid() {
            createTx = res
            return
        }
        if lightningSession?.logged ?? false {
            if let res = try await parseLightning() {
                createTx = res
                return
            }
        }
        if let res = try? await parsePsbtBitcoin() {
            createTx = res
            return
        }
        if let res = try? await parsePsbtLiquid() {
            createTx = res
            return
        }
        throw TransactionError.invalid(localizedDescription: "id_invalid_address".localized)
    }

    func lightningTransaction() async -> Transaction? {
        var tx = Transaction([:], subaccountId: lightningSubaccount?.id)
        if let addressee = createTx?.addressee {
            tx.addressees = [addressee]
        }
        var created = try? await lightningSession?.createTransaction(tx: tx)
        created?.subaccountId = lightningSubaccount?.id
        return created
    }
    
    func sendTxConfirmViewModel() async -> SendTxConfirmViewModel {
        SendTxConfirmViewModel(
            transaction: await lightningTransaction(),
            subaccount: lightningSubaccount,
            denominationType: settings?.denomination ?? .Sats,
            isFiat: false,
            txType: createTx?.txType ?? .transaction, 
            unsignedPsbt: nil,
            signedPsbt: nil)
    }

    func accountAssetViewModel() -> AccountAssetViewModel {
        let isBitcoin = createTx?.isBitcoin ?? true
        return AccountAssetViewModel(
            accounts: isBitcoin ? bitcoinSubaccountsWithFunds : liquidSubaccountsWithFunds,
            createTx: createTx,
            funded: true,
            showBalance: true)
    }
    
    func sendPsbtConfirmViewModel() async throws -> SendTxConfirmViewModel {
        var subaccount = preferredAccount ?? wm?.bitcoinSubaccounts.first
        if Wally.isPsbtElements(createTx?.psbt ?? "") ?? false {
            subaccount = wm?.liquidSubaccounts.first
        }
        let session = subaccount?.session
        var tx = try await session?.psbtGetDetails(params: PsbtGetDetailParams(psbt:  createTx?.psbt, utxos: [:]))
        let addressee = tx?.transactionOutputs?.map { Addressee.from(address: $0.address ?? "", satoshi: $0.satoshi, assetId: $0.assetId) }
        tx?.addressees = addressee ?? []
        tx?.subaccountId = subaccount?.id
        return SendTxConfirmViewModel(
            transaction: tx,
            subaccount: subaccount,
            denominationType: wm?.prominentSession?.settings?.denomination ?? .Sats,
            isFiat: false,
            txType: .psbt,
            unsignedPsbt: nil,
            signedPsbt: createTx?.psbt)
    }
}
