import Foundation

extension String {
    var htmlDecoded: String {
        let decoded = try? NSAttributedString(data: Data(utf8), options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ], documentAttributes: nil).string
        return decoded ?? self
    }
}

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

    func localized(_ lang: String) -> String {
        let path = Bundle.main.path(forResource: lang, ofType: "lproj")
        let bundle = Bundle(path: path!)
        return NSLocalizedString(self, tableName: nil, bundle: bundle!, value: "", comment: "\(self)_comment")
    }

    public var localized: String {
        let lang = LangHelper.shared.cachedCLang.code
        return localized(lang)
    }

    public func localizedFormat(withArguments args: CVarArg...) -> String {
        return String(format: self.localized, arguments: args)
    }
}
