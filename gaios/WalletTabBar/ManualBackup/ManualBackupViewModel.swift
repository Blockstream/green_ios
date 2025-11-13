class ManualBackupViewModel {
    var flowType = BackupFlowType.phrase
    init(_ flowType: BackupFlowType) {
        self.flowType = flowType
    }

    var navTitle: String {
        "id_back_up_your_wallet".localized
    }
    var title: String {
        "id_manual_backup".localized
    }
    var info1: String {
        "id_offline_written_backup".localized
    }
    var info2: String {
        "id_access_wallet_on_a_new_device".localized
    }
    var info3: String {
        "id_instant_recovery".localized
    }
    var btnTitle: String {
        switch flowType {
        case .addSubaccount:
            return "Create Recovery Key for 2of3 account".localized
        default:
            return "Back Up Recovery Phrase".localized
        }
    }
    var chooselengthTitle: String {
        switch flowType {
        case .addSubaccount:
            return "Choose between a 12 words or 24 words for the 2of3 recovery key.".localized
        default:
            return "id_new_recovery_phrase".localized
        }
    }
}
