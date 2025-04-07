import Foundation
import core
enum BackupAlertPosition {
    case homeTab
    case securityTab
    case buy
    case receive
}
class BackupHelper {

    static let shared = BackupHelper()
    private var dismissedCache: [(String, BackupAlertPosition)] = []

    private func walletsInBackupList() -> [String] {
        if let walletsToBackup: [String] = UserDefaults.standard.object(forKey: AppStorageConstants.walletsToBackup.rawValue) as? [String] {
            return walletsToBackup
        }
        return []
    }
    func addToBackupList(_ walletId: String?) {
        guard let walletId = walletId else { return }
        var walletsToBackup: [String] = self.walletsInBackupList()
        if !walletsToBackup.contains(walletId) {
            walletsToBackup.append(walletId)
            UserDefaults.standard.set(walletsToBackup, forKey: AppStorageConstants.walletsToBackup.rawValue)
        }
    }
    func removeFromBackupList(_ walletId: String?) {
        guard let walletId = walletId else { return }
        var walletsToBackup: [String] = self.walletsInBackupList()
        if let index = walletsToBackup.firstIndex(of: walletId) {
            walletsToBackup.remove(at: index)
        }
        UserDefaults.standard.set(walletsToBackup, forKey: AppStorageConstants.walletsToBackup.rawValue)
    }
    func needsBackup(walletId: String?) -> Bool {
        guard let walletId = walletId else { return false }
        return self.walletsInBackupList().contains(walletId)
    }
    func addToDismissed(walletId: String?, position: BackupAlertPosition) {
        guard let walletId = walletId else { return }
        self.dismissedCache.append((walletId, position))
    }
    func isDismissed(walletId: String?, position: BackupAlertPosition) -> Bool {
        guard let walletId = walletId else { return false }
        return dismissedCache.contains(where: { $0.0 == walletId && $0.1 == position })
    }
    func cleanDismissedCache(walletId: String?) {
        guard let walletId = walletId else { return }
        dismissedCache.removeAll(where: { $0.0 == walletId })
    }
    func cleanDismissedCache(walletId: String?, position: BackupAlertPosition) {
        guard let walletId = walletId else { return }
        dismissedCache.removeAll(where: { $0.0 == walletId && $0.1 == position })
    }
}
