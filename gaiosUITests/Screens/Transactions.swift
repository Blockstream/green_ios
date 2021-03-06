import XCTest

class Transactions: Screen {

    override var rootElement: XCUIElement {
        return app.tables[AccessibilityIdentifiers.TransactionsScreen.view]
    }
    
    @discardableResult
    func tapSettings() -> Self {
        tap(button: AccessibilityIdentifiers.TransactionsScreen.settingsBtn)
        return self
    }

    @discardableResult
    func tapReceive() -> Self {
        tap(app.otherElements[AccessibilityIdentifiers.TransactionsScreen.receiveView])
        return self
    }
    
    @discardableResult
    func tapSend() -> Self {
        tap(app.otherElements[AccessibilityIdentifiers.TransactionsScreen.sendView])
        return self
    }
}
