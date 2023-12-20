import Foundation

import gdk

class SendConfirmViewModel {
    
    var wm: WalletManager? { WalletManager.current }
    var account: WalletItem
    var tx: Transaction
    var addresseeCellModels: [AddresseeCellModel]
    var session: SessionManager { account.session! }
    var remoteAlert: RemoteAlert?
    var isLightning: Bool { account.gdkNetwork.lightning }
    var isHW: Bool { wm?.account.isHW ?? false }
    var isLedger: Bool { wm?.account.isLedger ?? false }
    var inputDenomination: DenominationType
    var sendAll: Bool { tx.addressees.first?.isGreedy ?? false }
    
    var inputType: TxType = .transaction // for analytics
    var addressInputType: AnalyticsManager.AddressInputType? = .paste // for analytics

    init(account: WalletItem, tx: Transaction, inputDenomination: DenominationType, inputType: TxType, addressInputType: AnalyticsManager.AddressInputType? = nil) {
        self.account = account
        self.tx = tx
        self.inputDenomination = inputDenomination
        self.addresseeCellModels = [AddresseeCellModel(tx: tx, index: 0, inputDenomination: inputDenomination)]
        self.remoteAlert = RemoteAlertManager.shared.alerts(screen: .sendConfirm, networks: wm?.activeNetworks ?? []).first
        self.inputType = inputType
        self.addressInputType = addressInputType
    }
    
    private func _send() async throws -> SendTransactionSuccess {
        if wm?.hwDevice != nil {
            let bleDevice = BleViewModel.shared
            if !bleDevice.isConnected() {
                try await bleDevice.connect()
                _ = try await bleDevice.authenticating()
            }
        }
        let liquid = tx.subaccountItem?.gdkNetwork.liquid
        if liquid ?? false {
            tx = try await session.blindTransaction(tx: tx)
        }
        try await tx = session.signTransaction(tx: tx)
        if tx.isSweep {
            return try await session.broadcastTransaction(txHex: tx.transaction ?? "")
        } else {
            return try await session.sendTransaction(tx: tx)
        }
    }
    
    func send() async throws -> SendTransactionSuccess {
        AnalyticsManager.shared.startSendTransaction()
        AnalyticsManager.shared.startFailedTransaction()
        let withMemo = !(tx.memo?.isEmpty ?? true)
        let transSgmt = AnalyticsManager.TransactionSegmentation(
            transactionType: inputType,
            addressInputType: addressInputType,
            sendAll: sendAll)
        do {
            let res = try await _send()
            AnalyticsManager.shared.endSendTransaction(
                account: AccountsRepository.shared.current,
                walletItem: account,
                transactionSgmt: transSgmt,
                withMemo: withMemo)
            
            if sendAll { sendAllEvent() }

            return res
        } catch {
            AnalyticsManager.shared.failedTransaction(
                account: AccountsRepository.shared.current,
                walletItem: account,
                transactionSgmt: transSgmt,
                withMemo: withMemo,
                prettyError: error.description()?.localized)
            throw error
        }
    }

    func sendAllEvent() {
        let wm = WalletManager.current
        if let subaccounts = wm?.subaccounts {
            var accountsFunded: Int = 0
            wm!.subaccounts.forEach { item in
                let assets = item.satoshi ?? [:]
                for (_, value) in assets where value > 0 {
                        accountsFunded += 1
                        break
                }
            }
            let walletFunded: Bool = accountsFunded > 0
            let accounts: Int = subaccounts.count
            let accountsTypes: String = Array(Set(subaccounts.map { $0.type.rawValue })).sorted().joined(separator: ",")
            AnalyticsManager.shared.accountEmptied(account: AccountsRepository.shared.current,
                                                   walletData: AnalyticsManager.WalletData(walletFunded: walletFunded,
                                                                                         accountsFunded: accountsFunded,
                                                                                         accounts: accounts,
                                                                                         accountsTypes: accountsTypes))
        }
    }
}
