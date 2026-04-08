import Foundation
import OSLog

public var logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "Green")

public var lwkLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "Lwk")

public var lightningLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "Lightning")


extension Logger {

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
        if category == "Lwk" {
            return basePath.appendingPathComponent("Lwk.log")
        } else if category == "Lightning" {
            return basePath.appendingPathComponent("Greenlight.log")
        } else {
            return basePath.appendingPathComponent("Green.log")
        }
    }

    public func write(category: String) {
        let contents = export(category: category).joined(separator: "\n").data(using: .utf8)
        let _ = FileManager.default.createFile(atPath: logFile(category: category).path, contents: contents, attributes: nil)
    }
}
