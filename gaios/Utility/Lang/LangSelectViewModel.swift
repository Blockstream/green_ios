import Foundation
import UIKit

class LangSelectViewModel {

    var langList: [Lang] {
        LangHelper.shared.cachedLangList
    }

    var cLang: Lang {
        LangHelper.shared.cachedCLang
    }

    func update(_ idx: Int) {
        LangHelper.shared.update(idx)
    }

    func newLang(_ idx: Int) -> Lang? {
        LangHelper.shared.newLang(idx)
    }

    func resetToSystemLanguage() {
        LangHelper.shared.resetToSystemLanguage()
    }
}
