import Foundation

struct Lang {
    var code: String
    var name: String
}

class LangHelper {

    static let shared = LangHelper()

    private var cLang = Lang(code: "en", name: "English")
    private var dLang = Lang(code: "en", name: "English")
    private var langList = [Lang]()

    init() {
        self.langList = getLangList()
        self.cLang = getCLang()
    }

    private func getCLang() -> Lang {

        if let langCode =  UserDefaults.standard.string(forKey: "langCode") {
            let canditates = langList.filter { $0.code == langCode }
            if let candidate = canditates.first {
                return candidate
            }
        }
        let systemCode = Locale.current.languageCode
        let canditates = langList.filter { $0.code == systemCode }
        if let candidate = canditates.first {
            return candidate
        }
        return dLang
    }

    private func getLangList() -> [Lang] {
        guard let contentsURLs = try? FileManager.default.contentsOfDirectory(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil) else { return [] }
        let identifiers = contentsURLs.compactMap { anURL -> String? in
            guard anURL.pathExtension == "lproj" else { return nil }
            return anURL.deletingPathExtension().lastPathComponent
        }
        var langList: [Lang] = []
        for idn in identifiers {
            if let name = Locale.current.localizedString(forIdentifier: idn)?.localizedCapitalized {
                langList.append(Lang(code: idn, name: name))
            }
        }
        return langList
    }

    func update(_ idx: Int) {
        if let lang = langList[safe: idx] {
            UserDefaults.standard.setValue(lang.code, forKey: "langCode")
            cLang = getCLang()
        }
    }

    func resetToSystemLanguage() {
        UserDefaults.standard.removeObject(forKey: "langCode")
        cLang = getCLang()
    }

    func newLang(_ idx: Int) -> Lang? {
        if let lang = langList[safe: idx] {
            return lang
        }
        return nil
    }

    var cachedCLang: Lang {
        return cLang
    }

    var cachedLangList: [Lang] {
        return langList
    }
}
