import Foundation
import gdk
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
}

extension AnalyticsManager {

    public func activeWalletStart() {
        let event: AnalyticsEventName = AppSettings.shared.gdkSettings?.tor ?? false ? .walletActiveTor : .walletActive
        startTrace(event)
        cancelEvent(event)
        startEvent(event)
    }

    public func activeWalletEnd(account: Account?, walletData: WalletData) {
        let event: AnalyticsEventName = AppSettings.shared.gdkSettings?.tor ?? false ? .walletActiveTor : .walletActive
        endTrace(event)
        var s = sessSgmt(account)
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

    public func loginWalletEnd(account: Account, loginType: AnalyticsManager.LoginType) {
        let event: AnalyticsEventName = AppSettings.shared.gdkSettings?.tor ?? false ? .walletLoginTor : .walletLogin
        endTrace(event)
        var s = sessSgmt(account)
        s[AnalyticsManager.strMethod] = loginType.rawValue
        s[AnalyticsManager.strEphemeralBip39] = "\(account.isEphemeral)"
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

    public func renameAccount(account: Account?, walletItem: WalletItem?) {
        let s = subAccSeg(account, walletItem: walletItem)
        recordEvent(.renameAccount, sgmt: s)
    }

    public func startSendTransaction() {
        startTrace(.sendTransaction)
        cancelEvent(.sendTransaction)
        startEvent(.sendTransaction)
    }

    public func endSendTransaction(account: Account?, walletItem: WalletItem?, transactionSgmt: AnalyticsManager.TransactionSegmentation, withMemo: Bool) {
        endTrace(.sendTransaction)
        var s = subAccSeg(account, walletItem: walletItem)
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
        endEvent(.sendTransaction, sgmt: s)
    }

    public func createWallet(account: Account?) {
        let s = sessSgmt(account)
        AnalyticsManager.shared.userPropertiesDidChange()
        recordEvent(.walletCreate, sgmt: s)
    }

    public func importWallet(account: Account?) {
        let s = sessSgmt(account)
        AnalyticsManager.shared.userPropertiesDidChange()
        recordEvent(.walletImport, sgmt: s)
    }

    public func createAccount(account: Account?, walletItem: WalletItem?) {
        let s = subAccSeg(account, walletItem: walletItem)
        recordEvent(.createAccount, sgmt: s)
    }

    public func receiveAddress(account: Account?, walletItem: WalletItem?, data: ReceiveAddressData) {
        var s = subAccSeg(account, walletItem: walletItem)
        s[AnalyticsManager.strType] = data.type.rawValue
        s[AnalyticsManager.strMedia] = data.media.rawValue
        s[AnalyticsManager.strMethod] = data.method.rawValue
        recordEvent(.receiveAddress, sgmt: s)
    }

    public func shareTransaction(account: Account?, isShare: Bool) {
        var s = sessSgmt(account)
        s[AnalyticsManager.strMethod] = isShare ? AnalyticsManager.strShare : AnalyticsManager.strCopy
        recordEvent(.shareTransaction, sgmt: s)
    }

    public func failedWalletLogin(account: Account?, error: Error, prettyError: String?) {
        let event: AnalyticsEventName = AppSettings.shared.gdkSettings?.tor ?? false ? .failedWalletLoginTor : .failedWalletLogin
        var s = sessSgmt(account)
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
        account: Account?,
        walletItem: WalletItem?,
        transactionSgmt: AnalyticsManager.TransactionSegmentation,
        withMemo: Bool,
        prettyError: String?,
        nodeId: String?) {
        endTrace(.failedTransaction)
        var s = subAccSeg(account, walletItem: walletItem)
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
        endTrace(.failedTransaction)
        endEvent(.failedTransaction, sgmt: s)
    }

    public func recoveryPhraseCheckFailed(onBoardParams: OnBoardParams?, page: Int) {
        let sgmt = [AnalyticsManager.strPage: "\(page)" ]
        recordEvent(.failedRecoveryPhraseCheck, sgmt: sgmt)
    }

    public func appReview(account: Account?, walletItem: WalletItem?) {
        let s = subAccSeg(account, walletItem: walletItem)
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

    public func onAccountFirst(account: Account?) {
        let s = sessSgmt(account)
        recordEvent(.accountFirst, sgmt: s)
    }

    public func convertBalance(account: Account?) {
        let s = sessSgmt(account)
        recordEvent(.balanceConvert, sgmt: s)
    }

    public func changeAsset(account: Account?) {
        let s = sessSgmt(account)
        recordEvent(.assetChange, sgmt: s)
    }

    public func selectAsset(account: Account?) {
        let s = sessSgmt(account)
        recordEvent(.assetSelect, sgmt: s)
    }

    public func selectAccount(account: Account?, walletItem: WalletItem?) {
        let s = subAccSeg(account, walletItem: walletItem)
        recordEvent(.accountSelect, sgmt: s)
    }

    public func newAccount(account: Account?) {
        let s = sessSgmt(account)
        recordEvent(.accountNew, sgmt: s)
    }

    public func hwwConnect(account: Account?) {
        var s = sessSgmt(account)

        s.removeValue(forKey: "\(AnalyticsManager.strFirmware)")
        s.removeValue(forKey: "\(AnalyticsManager.strModel)")

        recordEvent(.connectHWW, sgmt: s)
    }

    public func hwwConnected(account: Account?) {
        let s = sessSgmt(account)

        // s[AnalyticsManager.strFirmware] = BleViewModel.shared.jade?.version?.jadeVersion ?? ""
        // s[AnalyticsManager.strModel] = BleViewModel.shared.jade?.version?.boardType ?? ""
        recordEvent(.connectedHWW, sgmt: s)
    }

    public func hwwConnected(account: Account?, fwVersion: String?, model: String?) {
        var s = sessSgmt(account)

        s.removeValue(forKey: "\(AnalyticsManager.strFirmware)")
        s.removeValue(forKey: "\(AnalyticsManager.strModel)")
        if let fwVersion = fwVersion, let model = model {
            s[AnalyticsManager.strFirmware] = fwVersion
            s[AnalyticsManager.strModel] = model
        }
        recordEvent(.connectedHWW, sgmt: s)
    }

    public func initializeJade(account: Account?) {
        let s = sessSgmt(account)
        recordEvent(.jadeInitialize, sgmt: s)
    }

    public func verifyAddressJade(account: Account?, walletItem: WalletItem?) {
        let s = subAccSeg(account, walletItem: walletItem)
        recordEvent(.jadeVerifyAddress, sgmt: s)
    }

    public func otaStartJade(account: Account?, firmware: Firmware) {
        let s = firmwareSgmt(account, firmware: firmware)
        recordEvent(.jadeOtaStart, sgmt: s)
        cancelEvent(.jadeOtaComplete)
        startEvent(.jadeOtaComplete)
    }

    public func otaCompleteJade(account: Account?, firmware: Firmware) {
        let s = firmwareSgmt(account, firmware: firmware)
        endEvent(.jadeOtaComplete, sgmt: s)
    }

    public func otaRefuseJade(account: Account?) {
        let s = sessSgmt(account)
        recordEvent(.jadeOtaRefuse, sgmt: s)
    }

    public func otaFailedJade(account: Account?, error: String?) {
        var s = sessSgmt(account)
        s[AnalyticsManager.strError] = error ?? ""
        recordEvent(.jadeOtaFailed, sgmt: s)
    }

    public func scanQr(account: Account?, screen: QrScanScreen) {
        switch screen {
        case .addAccountPK, .send, .walletOverview:
            var s = sessSgmt(account)
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

    public func accountEmptied(account: Account?, walletItem: WalletItem, walletData: WalletData) {
        var s = sessSgmt(account)
        s[AnalyticsManager.strWalletFunded] = walletData.walletFunded ? "true" : "false"
        s[AnalyticsManager.strAccountsFunded] = "\(walletData.accountsFunded)"
        s[AnalyticsManager.strAccounts] = "\(walletData.accounts)"
        s[AnalyticsManager.strAccountsTypes] = walletData.accountsTypes
        s[AnalyticsManager.strAccountType] = walletItem.type.rawValue
        s[AnalyticsManager.strNetwork] = accountNetworkLabel(walletItem.gdkNetwork)

        recordEvent(.accountEmptied, sgmt: s)
    }

    public func preferredUnits(account: Account?) {
        let s = sessSgmt(account)
        recordEvent(.preferredUnits, sgmt: s)
    }

    public func hideAmount(account: Account?) {
        let s = sessSgmt(account)
        recordEvent(.hideAmount, sgmt: s)
    }

    public func promoImpression(account: Account?, promoId: String, screen: String) {
        var s = sessSgmt(account)
        s[AnalyticsManager.strPromoId] = promoId
        s[AnalyticsManager.strScreen] = screen
        recordEvent(.promoImpression, sgmt: s)
    }

    public func promoDismiss(account: Account?, promoId: String, screen: String) {
        var s = sessSgmt(account)
        s[AnalyticsManager.strPromoId] = promoId
        s[AnalyticsManager.strScreen] = screen
        recordEvent(.promoDismiss, sgmt: s)
    }

    public func promoOpen(account: Account?, promoId: String, screen: String) {
        var s = sessSgmt(account)
        s[AnalyticsManager.strPromoId] = promoId
        s[AnalyticsManager.strScreen] = screen
        recordEvent(.promoOpen, sgmt: s)
    }

    public func promoAction(account: Account?, promoId: String, screen: String) {
        var s = sessSgmt(account)
        s[AnalyticsManager.strPromoId] = promoId
        s[AnalyticsManager.strScreen] = screen
        recordEvent(.promoAction, sgmt: s)
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
