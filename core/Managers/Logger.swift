import Foundation
import OSLog

public enum LoggerCategory: String, CaseIterable {
    case app = "App"
    case gdk = "Gdk"
    case lightning = "Lightning"
    case lwk = "Lwk"
}
public var logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: LoggerCategory.app.rawValue)

public var lwkLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: LoggerCategory.lwk.rawValue)

public var lightningLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: LoggerCategory.lightning.rawValue)

public var gdkLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: LoggerCategory.gdk.rawValue)

extension Logger {

    public func export(category: LoggerCategory) -> [String] {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(timeIntervalSinceLatestBoot: 1)
            let logs = try store
                .getEntries(at: position)
                .compactMap { $0 as? OSLogEntryLog }
                .filter {
                    $0.subsystem == Bundle.main.bundleIdentifier! && (
                        category.rawValue == $0.category
                    )
                }
                .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }

            return logs
        } catch {
            return []
        }
    }

    public func logFile(category: LoggerCategory) -> URL {
        let basePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return basePath.appendingPathComponent("\(category.rawValue).log")
    }

    public func write(category: LoggerCategory) {
        let contents = export(category: category).joined(separator: "\n").data(using: .utf8)
        _ = FileManager.default.createFile(atPath: logFile(category: category).path, contents: contents, attributes: nil)
    }
}
