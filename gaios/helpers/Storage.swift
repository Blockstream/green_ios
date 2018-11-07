import Foundation

class Storage {

    static func getDocumentsURL() -> URL? {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return url
        } else {
            return nil
        }
    }

    static func wipeSettings(path: String) {
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent(path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as NSError {
            print("Error: \(error.domain)")
        }
    }

    static func wipeNotifications(path: String) {
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent(path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as NSError {
            print("Error: \(error.domain)")
        }
    }

    static func getSettingsPath() -> String {
        if(getNetwork() == .MainNet) {
            return "settings_mainnet.json"
        } else {
            return "settings_testnet.json"
        }
    }

    static func getNotificationPath() -> String {
        if(getNetwork() == .MainNet) {
            return "notification_mainnet.json"
        } else {
            return "notification_testnet.json"
        }
    }

    static func wipeAll() {
        wipeSettings(path: getSettingsPath())
        wipeNotifications(path: getNotificationPath())
    }
}
