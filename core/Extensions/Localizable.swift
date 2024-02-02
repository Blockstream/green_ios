import Foundation
import UIKit

// MARK: Localizable
protocol Localizable {
    /// Simple string localization
    var localized: String { get }

    /// String with parameters
    /// Example: string "" = "You have no access, error: %@"
    /// Usage: "no_access_error_message".localizedFormat(withArguments: "\(errorDescription)")
    func localizedFormat(withArguments args: CVarArg...) -> String
}

extension String: Localizable {
    public var localized: String {
        return NSLocalizedString(self, comment: "\(self)_comment")
    }

    public func localizedFormat(withArguments args: CVarArg...) -> String {
        return String(format: self.localized, arguments: args)
    }
}
