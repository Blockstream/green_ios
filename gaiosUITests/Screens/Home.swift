import XCTest

class Home: Screen {

    override var rootElement: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.HomeScreen.view]
    }
    
    @discardableResult
    func tapAddWalletView(connectionTimeout: TimeInterval = 25) -> Self {
        
        let lastCell = rootElement.tables.firstMatch.cells.allElementsBoundByIndex.last
        let MAX_SCROLLS = 10
        var count = 0
        while lastCell!.isHittable == false && count < MAX_SCROLLS {
            rootElement.tables.firstMatch.swipeUp()
            count += 1
        }
        tap(app.otherElements[AccessibilityIdentifiers.HomeScreen.addWalletView])
        return self
    }
    
    @discardableResult
    func existsWallet(named name: String, connectionTimeout: TimeInterval = 25) -> Bool {
        let walletExist = NSPredicate(format: "label MATCHES '\(name)'")
        let walletLabel = app.otherElements[AccessibilityIdentifiers.HomeScreen.view].tables
            .children(matching: .cell).staticTexts.element(matching: walletExist)
        var existsWallet = walletLabel.waitForExistence(timeout: 3)

        var swipeUpTimes = 0
        while (!existsWallet || !walletLabel.isHittable) && swipeUpTimes < maxSwipeUp {
//            rootElement.tables.cells.element(boundBy: 0).swipeUp()
            rootElement.tables.firstMatch.swipeUp()
            swipeUpTimes += 1

            existsWallet = walletLabel.exists
        }

        return existsWallet && walletLabel.isHittable
    }
    
    @discardableResult
    func selectWallet(named name: String, connectionTimeout: TimeInterval = 25) -> Self {
        let walletExist = NSPredicate(format: "label MATCHES '\(name)'")
        let walletLabel = app.otherElements[AccessibilityIdentifiers.HomeScreen.view].tables
            .children(matching: .cell).staticTexts.element(matching: walletExist)
        var existsWallet = walletLabel.waitForExistence(timeout: 3)

        var swipeUpTimes = 0
        while !existsWallet && swipeUpTimes < maxSwipeUp {
            rootElement.tables.cells.element(boundBy: 0).swipeUp()
            swipeUpTimes += 1

            existsWallet = walletLabel.exists
        }

        return tap(walletLabel)
    }
    
    @discardableResult
    func tapAppSettings() -> Self {
        tap(button: AccessibilityIdentifiers.HomeScreen.appSettingsBtn)
        return self
    }
}
