import Foundation

import hw

public enum AnalyticsEventName: String {
    case debugEvent = "debug_event"
    case walletActive = "wallet_active"
    case walletActiveTor = "wallet_active_tor"
    case walletLogin = "wallet_login"
    case walletLoginTor = "wallet_login_tor"
    case lightningLogin = "lightning_login"
    case walletCreate = "wallet_create"
    case walletImport = "wallet_import"
    case renameWallet = "wallet_rename"
    case deleteWallet = "wallet_delete"
    case renameAccount = "account_rename"
    case createAccount = "account_create"
    case sendTransaction = "send_transaction"
    case receiveAddress = "receive_address"
    case shareTransaction = "share_transaction"
    case failedWalletLogin = "failed_wallet_login"
    case failedWalletLoginTor = "failed_wallet_login_tor"
    case failedRecoveryPhraseCheck = "failed_recovery_phrase_check"
    case failedTransaction = "failed_transaction"
    case appReview = "app_review"

    case walletAdd = "wallet_add"
    case walletNew = "wallet_new"
    case walletHWW = "wallet_hww"
    case walletWO = "wallet_wo"
    case walletRestore = "wallet_restore"
    case accountFirst = "account_first"
    case balanceConvert = "balance_convert"
    case assetChange = "asset_change"
    case assetSelect = "asset_select"
    case accountSelect = "account_select"
    case accountNew = "account_new"
    case connectHWW = "hww_connect"
    case connectedHWW = "hww_connected"

    case jadeInitialize = "jade_initialize"
    case jadeVerifyAddress = "verify_address"
    case jadeOtaStart = "ota_start"
    case jadeOtaComplete = "ota_complete"
    case jadeOtaRefuse = "ota_refuse"
    case jadeOtaFailed = "ota_failed"

    case qrScan = "qr_scan"

    case accountEmptied = "account_emptied"
    case preferredUnits = "preferred_units"
    case hideAmount = "hide_amount"

    case promoImpression = "promo_impression"
    case promoOpen = "promo_open"
    case promoDismiss = "promo_dismiss"
    case promoAction = "promo_action"

    case buyInitiate = "buy_initiate"
    case buyRedirect = "buy_redirect"
    case getStarted = "get_started"
    case setupSww = "setup_sww"
    case swwCreated = "sww_created"
    case backupManual = "backup_manual"

    case swapToggle = "swap_toggle"
    case swapReceive = "swap_receive"
    case swapSend = "swap_send"
    case swapInternal = "swap_internal"
    case swapEntry = "swap_entry"
    case swapInitiate = "swap_initiate"
    case swapSetup = "swap_setup"
    case swapEnable = "swap_enable"

    case invoiceCreate = "invoice_create"
    case sendAttempt = "send_attempt"
    case enableStart = "enable_start"
    case enableFailed = "enable_failed"
}

extension AnalyticsManager {

    public func activeWalletStart() {
        let event: AnalyticsEventName = AppSettings.shared.gdkSettings?.tor ?? false ? .walletActiveTor : .walletActive
        startTrace(event)
        cancelEvent(event)
        startEvent(event)
    }

    public func activeWalletEnd(for wallet: Wallet?, walletData: WalletData) {
        let event: AnalyticsEventName = AppSettings.shared.gdkSettings?.tor ?? false ? .walletActiveTor : .walletActive
        endTrace(event)
        var s = sessSgmt(wallet)
        s[AnalyticsManager.strWalletFunded] = walletData.walletFunded ? "true" : "false"
        s[AnalyticsManager.strAccountsFunded] = "\(walletData.accountsFunded)"
        s[AnalyticsManager.strAccounts] = "\(walletData.accounts)"
        s[AnalyticsManager.strAccountsTypes] = walletData.accountsTypes
        endEvent(event, sgmt: s)
    }

    public func loginWalletStart() {
        let event: AnalyticsEventName = AppSettings.shared.gdkSettings?.tor ?? false ? .walletLoginTor : .walletLogin
        startTrace(event)
        cancelEvent(event)
        startEvent(event)
    }

    public func loginWalletEnd(wallet: Wallet, loginType: AnalyticsManager.LoginType) {
        let event: AnalyticsEventName = AppSettings.shared.gdkSettings?.tor ?? false ? .walletLoginTor : .walletLogin
        endTrace(event)
        var s = sessSgmt(wallet)
        s[AnalyticsManager.strMethod] = loginType.rawValue
        s[AnalyticsManager.strEphemeralBip39] = "\(wallet.isEphemeral)"
        endEvent(.walletLogin, sgmt: s)
    }

    public func loginLightningStart() {
        startTrace(.lightningLogin)
    }

    public func loginLightningStop() {
        endTrace(.lightningLogin)
    }

    public func renameWallet() {
        recordEvent(.renameWallet)
    }

    public func deleteWallet() {
        AnalyticsManager.shared.userPropertiesDidChange()
        recordEvent(.deleteWallet)
    }

    public func renameAccount(wallet: Wallet?, account: Account?) {
        let s = subAccSeg(wallet, account: account)
        recordEvent(.renameAccount, sgmt: s)
    }

    public func startSendTransaction() {
        startTrace(.sendTransaction)
        cancelEvent(.sendTransaction)
        startEvent(.sendTransaction)
    }

    public func endSendTransaction(wallet: Wallet?,
                                   account: Account?,
                                   transactionSgmt: AnalyticsManager.TransactionSegmentation,
                                   withMemo: Bool,
                                   invoiceType: AnalyticsInvoiceType?) {
        endTrace(.sendTransaction)
        var s = subAccSeg(wallet, account: account)
        switch transactionSgmt.transactionType {
        case .transaction:
            s[AnalyticsManager.strTransactionType] = AnalyticsManager.TransactionType.send.rawValue
        case .sweep:
            s[AnalyticsManager.strTransactionType] = AnalyticsManager.TransactionType.sweep.rawValue
        case .bumpFee:
            s[AnalyticsManager.strTransactionType] = AnalyticsManager.TransactionType.bump.rawValue
        default:
            break
        }
        s[AnalyticsManager.strAddressInput] = (transactionSgmt.addressInputType ?? .paste).rawValue
        // s[AnalyticsManager.strSendAll] = transactionSgmt.sendAll ? "true" : "false"
        s[AnalyticsManager.strWithMemo] = withMemo ? "true" : "false"
        if let invoiceType {
            s[AnalyticsManager.strInvoiceType] = invoiceType.rawValue
        }
        endEvent(.sendTransaction, sgmt: s)
    }

    public func createWallet(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        AnalyticsManager.shared.userPropertiesDidChange()
        recordEvent(.walletCreate, sgmt: s)
    }

    public func importWallet(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        AnalyticsManager.shared.userPropertiesDidChange()
        recordEvent(.walletImport, sgmt: s)
    }

    public func createAccount(wallet: Wallet?, account: Account?) {
        let s = subAccSeg(wallet, account: account)
        recordEvent(.createAccount, sgmt: s)
    }

    public func receiveAddress(wallet: Wallet?, account: Account?, data: ReceiveAddressData) {
        var s = subAccSeg(wallet, account: account)
        s[AnalyticsManager.strType] = data.type.rawValue
        s[AnalyticsManager.strMedia] = data.media.rawValue
        s[AnalyticsManager.strMethod] = data.method.rawValue
        recordEvent(.receiveAddress, sgmt: s)
    }

    public func shareTransaction(wallet: Wallet?, isShare: Bool) {
        var s = sessSgmt(wallet)
        s[AnalyticsManager.strMethod] = isShare ? AnalyticsManager.strShare : AnalyticsManager.strCopy
        recordEvent(.shareTransaction, sgmt: s)
    }

    public func failedWalletLogin(wallet: Wallet?, error: Error, prettyError: String?) {
        let event: AnalyticsEventName = AppSettings.shared.gdkSettings?.tor ?? false ? .failedWalletLoginTor : .failedWalletLogin
        var s = sessSgmt(wallet)
        if let prettyError = prettyError {
            s[AnalyticsManager.strError] = prettyError
        } else {
            s[AnalyticsManager.strError] = error.localizedDescription
        }
        recordEvent(event, sgmt: s)
    }

    public func startFailedTransaction() {
        startTrace(.failedTransaction)
        cancelEvent(.failedTransaction)
        startEvent(.failedTransaction)
    }

    public func failedTransaction(
        wallet: Wallet?,
        account: Account?,
        transactionSgmt: AnalyticsManager.TransactionSegmentation,
        withMemo: Bool,
        prettyError: String?,
        nodeId: String?,
        invoiceType: AnalyticsInvoiceType?) {
        var s = subAccSeg(wallet, account: account)
        switch transactionSgmt.transactionType {
        case .transaction:
            s[AnalyticsManager.strTransactionType] = AnalyticsManager.TransactionType.send.rawValue
        case .sweep:
            s[AnalyticsManager.strTransactionType] = AnalyticsManager.TransactionType.sweep.rawValue
        case .bumpFee:
            s[AnalyticsManager.strTransactionType] = AnalyticsManager.TransactionType.bump.rawValue
        default:
            break
        }
        s[AnalyticsManager.strAddressInput] = transactionSgmt.addressInputType?.rawValue
        // s[AnalyticsManager.strSendAll] = transactionSgmt.sendAll ? "true" : "false"
        s[AnalyticsManager.strWithMemo] = withMemo ? "true" : "false"
        if let prettyError = prettyError {
            s[AnalyticsManager.strError] = prettyError
        }
        if let nodeId = nodeId {
            s[AnalyticsManager.strNodeId] = nodeId
        }
        if let invoiceType {
            s[AnalyticsManager.strInvoiceType] = invoiceType.rawValue
        }
        endTrace(.failedTransaction)
        endEvent(.failedTransaction, sgmt: s)
    }

    public func recoveryPhraseCheckFailed(page: Int) {
        let sgmt = [AnalyticsManager.strPage: "\(page)" ]
        recordEvent(.failedRecoveryPhraseCheck, sgmt: sgmt)
    }

    public func appReview(wallet: Wallet?, account: Account?) {
        let s = subAccSeg(wallet, account: account)
        recordEvent(.appReview, sgmt: s)
    }

    public func addWallet() {
        recordEvent(.walletAdd)
    }

    public func newWallet() {
        recordEvent(.walletNew)
    }

    public func hwwWallet() {
        recordEvent(.walletHWW)
    }

    public func woWallet() {
        recordEvent(.walletWO)
    }

    public func restoreWallet() {
        recordEvent(.walletRestore)
    }

    public func onAccountFirst(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.accountFirst, sgmt: s)
    }

    public func convertBalance(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.balanceConvert, sgmt: s)
    }

    public func changeAsset(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.assetChange, sgmt: s)
    }

    public func selectAsset(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.assetSelect, sgmt: s)
    }

    public func selectAccount(wallet: Wallet?, account: Account?) {
        let s = subAccSeg(wallet, account: account)
        recordEvent(.accountSelect, sgmt: s)
    }

    public func newAccount(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.accountNew, sgmt: s)
    }

    public func hwwConnect(wallet: Wallet?) {
        var s = sessSgmt(wallet)

        s.removeValue(forKey: "\(AnalyticsManager.strFirmware)")
        s.removeValue(forKey: "\(AnalyticsManager.strModel)")

        recordEvent(.connectHWW, sgmt: s)
    }

    public func hwwConnected(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.connectedHWW, sgmt: s)
    }

    public func hwwConnected(wallet: Wallet?, fwVersion: String?, model: String?) {
        var s = sessSgmt(wallet)
        hwData = (fwVersion, model)
        s.removeValue(forKey: "\(AnalyticsManager.strFirmware)")
        s.removeValue(forKey: "\(AnalyticsManager.strModel)")
        s[AnalyticsManager.strFirmware] = hwData.fwVersion
        s[AnalyticsManager.strModel] = hwData.model
        recordEvent(.connectedHWW, sgmt: s)
    }

    public func initializeJade(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.jadeInitialize, sgmt: s)
    }

    public func verifyAddressJade(wallet: Wallet?, account: Account?) {
        let s = subAccSeg(wallet, account: account)
        recordEvent(.jadeVerifyAddress, sgmt: s)
    }

    public func otaStartJade(wallet: Wallet?, firmware: Firmware) {
        let s = firmwareSgmt(wallet, firmware: firmware)
        recordEvent(.jadeOtaStart, sgmt: s)
        cancelEvent(.jadeOtaComplete)
        startEvent(.jadeOtaComplete)
    }

    public func otaCompleteJade(wallet: Wallet?, firmware: Firmware) {
        let s = firmwareSgmt(wallet, firmware: firmware)
        endEvent(.jadeOtaComplete, sgmt: s)
    }

    public func otaRefuseJade(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.jadeOtaRefuse, sgmt: s)
    }

    public func otaFailedJade(wallet: Wallet?, error: String?) {
        var s = sessSgmt(wallet)
        s[AnalyticsManager.strError] = error ?? ""
        recordEvent(.jadeOtaFailed, sgmt: s)
    }

    public func scanQr(wallet: Wallet?, screen: QrScanScreen) {
        switch screen {
        case .addAccountPK, .send, .walletOverview:
            var s = sessSgmt(wallet)
            s[AnalyticsManager.strScreen] = screen.rawValue
            recordEvent(.qrScan, sgmt: s)
        case .onBoardRecovery:
            var s = onBoardSgmtUnified(flow: .strRestore)
            s[AnalyticsManager.strScreen] = screen.rawValue
            recordEvent(.qrScan, sgmt: s)
        case .onBoardWOCredentials:
            var s = onBoardSgmtUnified(flow: .watchOnly)
            s[AnalyticsManager.strScreen] = screen.rawValue
            recordEvent(.qrScan, sgmt: s)
        }
    }

    public func accountEmptied(wallet: Wallet?, account: Account, walletData: WalletData) {
        var s = sessSgmt(wallet)
        s[AnalyticsManager.strWalletFunded] = walletData.walletFunded ? "true" : "false"
        s[AnalyticsManager.strAccountsFunded] = "\(walletData.accountsFunded)"
        s[AnalyticsManager.strAccounts] = "\(walletData.accounts)"
        s[AnalyticsManager.strAccountsTypes] = walletData.accountsTypes
        s[AnalyticsManager.strAccountType] = account.type.rawValue
        s[AnalyticsManager.strNetwork] = walletNetworkLabel(account.gdkNetwork)
        recordEvent(.accountEmptied, sgmt: s)
    }

    public func preferredUnits(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.preferredUnits, sgmt: s)
    }

    public func hideAmount(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.hideAmount, sgmt: s)
    }

    public func promoImpression(wallet: Wallet?, promoId: String, screen: String) {
        var s = sessSgmt(wallet)
        s[AnalyticsManager.strPromoId] = promoId
        s[AnalyticsManager.strScreen] = screen
        recordEvent(.promoImpression, sgmt: s)
    }

    public func promoDismiss(wallet: Wallet?, promoId: String, screen: String) {
        var s = sessSgmt(wallet)
        s[AnalyticsManager.strPromoId] = promoId
        s[AnalyticsManager.strScreen] = screen
        recordEvent(.promoDismiss, sgmt: s)
    }

    public func promoOpen(wallet: Wallet?, promoId: String, screen: String) {
        var s = sessSgmt(wallet)
        s[AnalyticsManager.strPromoId] = promoId
        s[AnalyticsManager.strScreen] = screen
        recordEvent(.promoOpen, sgmt: s)
    }

    public func promoAction(wallet: Wallet?, promoId: String, screen: String) {
        var s = sessSgmt(wallet)
        s[AnalyticsManager.strPromoId] = promoId
        s[AnalyticsManager.strScreen] = screen
        recordEvent(.promoAction, sgmt: s)
    }

    public func buyInitiate(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.buyInitiate, sgmt: s)
    }
    public func buyRedirect(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.buyRedirect, sgmt: s)
    }
    public func getStarted() {
        recordEvent(.getStarted)
    }
    public func setupSww() {
        recordEvent(.setupSww)
    }
    public func swwCreated(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.swwCreated, sgmt: s)
    }
    public func backupManual(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.backupManual, sgmt: s)
    }
    public func swapToggle(wallet: Wallet?, from: String, to: String) {
        let s = swapSgmt(wallet, from: from, to: to)
        recordEvent(.swapToggle, sgmt: s)
    }
    public func swapReceive(wallet: Wallet?, from: String, to: String) {
        let s = swapSgmt(wallet, from: from, to: to)
        recordEvent(.swapReceive, sgmt: s)
    }
    public func swapSend(wallet: Wallet?, from: String, to: String) {
        let s = swapSgmt(wallet, from: from, to: to)
        recordEvent(.swapSend, sgmt: s)
    }
    public func swapInternal(wallet: Wallet?, from: String, to: String) {
        let s = swapSgmt(wallet, from: from, to: to)
        recordEvent(.swapInternal, sgmt: s)
    }
    public func swapEntry(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.swapEntry, sgmt: s)
    }
    public func swapInitiate(wallet: Wallet?, from: String, to: String) {
        let s = swapSgmt(wallet, from: from, to: to)
        recordEvent(.swapInitiate, sgmt: s)
    }
    public func swapSetup(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.swapSetup, sgmt: s)
    }
    public func swapEnable(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.swapEnable, sgmt: s)
    }
    public func invoiceCreate(wallet: Wallet?, account: Account?) {
        let s = subAccSeg(wallet, account: account)
        recordEvent(.invoiceCreate, sgmt: s)
    }
    public func sendAttempt(wallet: Wallet?,
                            account: Account?,
                            invoiceType: AnalyticsInvoiceType?
    ) {
        var s = subAccSeg(wallet, account: account)
        if let invoiceType {
            s[AnalyticsManager.strInvoiceType] = invoiceType.rawValue
        }
        recordEvent(.sendAttempt, sgmt: s)
    }
    public func enableStart(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.enableStart, sgmt: s)
    }
    public func enableFailed(wallet: Wallet?) {
        let s = sessSgmt(wallet)
        recordEvent(.enableFailed, sgmt: s)
    }
}

extension AnalyticsManager {

    public enum TransactionType: String {
        case send
        case sweep
        case bump
    }

    public enum AddressInputType: String {
        case paste
        case scan
        case bip21
    }

    public enum ReceiveAddressType: String {
        case address
        case uri
    }

    public enum ReceiveAddressMedia: String {
        case text
        case image
    }

    public enum ReceiveAddressMethod: String {
        case share
        case copy
    }

    public struct TransactionSegmentation {
        public let transactionType: TxType
        public let addressInputType: AddressInputType?
        public let sendAll: Bool
        public init(transactionType: TxType, addressInputType: AddressInputType?, sendAll: Bool) {
            self.transactionType = transactionType
            self.addressInputType = addressInputType
            self.sendAll = sendAll
        }
    }

    public struct WalletData {
        let walletFunded: Bool
        let accountsFunded: Int
        let accounts: Int
        let accountsTypes: String
        public init(walletFunded: Bool, accountsFunded: Int, accounts: Int, accountsTypes: String) {
            self.walletFunded = walletFunded
            self.accountsFunded = accountsFunded
            self.accounts = accounts
            self.accountsTypes = accountsTypes
        }
    }

    public struct ReceiveAddressData {
        let type: ReceiveAddressType
        let media: ReceiveAddressMedia
        let method: ReceiveAddressMethod
        public init(type: ReceiveAddressType, media: ReceiveAddressMedia, method: ReceiveAddressMethod) {
            self.type = type
            self.media = media
            self.method = method
        }
    }
}
