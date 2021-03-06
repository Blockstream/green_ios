import XCTest

class ChooseSecurity: Screen {

    override var rootElement: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.ChooseSecurityScreen.view]
    }

    @discardableResult
    func tapMultiSigCard() -> Self {
        tap(app.otherElements[AccessibilityIdentifiers.ChooseSecurityScreen.multiSigCard])
        return self
    }
}
