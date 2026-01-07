class TabSecurityVM: TabViewModel {
    var security: [SecuritySection] {
        state.security
    }
    var backupCards: [AlertCardType]  {
        fetchBackupCards()
    }
    func fetchBackupCards() -> [AlertCardType] {
        var cards: [AlertCardType] = []
        if BackupHelper.shared.needsBackup(walletId: mainAccount.id) &&
            BackupHelper.shared.isDismissed(walletId: mainAccount.id, position: .securityTab) == false {
            cards.append(.backup)
        }
        return cards
    }
}
