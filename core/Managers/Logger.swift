import Foundation
import OSLog

public var logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "Green")

extension Logger {

    @available(iOSApplicationExtension 15.0, *)
    public func export(category: String) -> [String] {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(timeIntervalSinceLatestBoot: 1)
            let logs = try store
                .getEntries(at: position)
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == Bundle.main.bundleIdentifier! && (category == $0.category)  }
                .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }

            return logs
        } catch {
            return []
        }
    }

    public func logFile(category: String) -> URL {
        let basePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if category == "Lightning"{
            if let nodeId = WalletManager.current?.lightningSession?.nodeState?.id {
                return basePath.appendingPathComponent("Greenlight_Logs_\(nodeId).txt")
            }
        }
        return basePath.appendingPathComponent("Greenlight_Logs.txt")
    }

    @available(iOSApplicationExtension 15.0, *)
    public func write(category: String) {
        let contents = export(category: category).joined(separator: "\n").data(using: .utf8)
        let _ = FileManager.default.createFile(atPath: logFile(category: category).path, contents: contents, attributes: nil)
    }
}
