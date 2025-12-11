class TabSecurityVM: TabViewModel {
    var security: [SecuritySection] {
        state.security
    }
    var backupCards: [AlertCardType]  {
        state.backupCards
    }
}
