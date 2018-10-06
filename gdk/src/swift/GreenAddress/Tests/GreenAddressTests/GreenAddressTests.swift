import XCTest
import Foundation

import PromiseKit

@testable import GreenAddress

class GreenAddressTests : XCTestCase {

    let DEFAULT_MNEMONIC: String = "tragic transfer mesh camera fish model bleak lumber never capital animal era " +
                                   "coffee shift flame across pitch pipe shiver castle crawl noble obtain response"


    func doLogin(network: Network) throws -> Session {
        let session : Session = try Session()

        let ex = expectation(description: "")

        let p1 = retry(session: session, network: network) { wrap { try session.connect(network: network, debug: true) } }
        let p2 = retry(session: session, network: network) { wrap { try session.registerUser(mnemonic: self.DEFAULT_MNEMONIC) } }
        let p3 = wrap { try session.login(mnemonic: self.DEFAULT_MNEMONIC) }

        _ = when(fulfilled: p1, p2, p3).done { _, _, _ in ex.fulfill(); }
        waitForExpectations(timeout: 15, handler: nil)

        return session
    }

    // Get the user to select an authentication factor from a list
    // For the test return the first one
    // In a GUI app would show a modal, except that if the list is empty there is no 2fa
    // and if the list has length 1 must return the one and only method
    func _selectAuthenticationFactor(factors: [AuthenticationFactor]) -> Promise<AuthenticationFactor?> {
        return Promise<AuthenticationFactor?> { seal in
            seal.fulfill((factors.count > 0) ? factors[0] : nil)
        }
    }

    // Get the user to input the 2fa code
    // For the test return the fixed code my hacked backend uses
    // In an actual app would prompt the user to enter the code sent to 'factor'
    func _getTwoFactorCode(factor: AuthenticationFactor?) -> Promise<String?> {
        return Promise<String?> { seal in
            seal.fulfill(factor == nil ? nil : "555555")
        }
    }

    // Given a 2fa operation, resolve 2fa and follow the chain recursively until done
    func resolveTwoFactor(op: TwoFactorCall?) throws -> Promise<TwoFactorCall?> {
        guard let op = op else {
            return Promise<TwoFactorCall?> { seal in seal.fulfill(nil) }
        }

        let factors: [AuthenticationFactor] = try op.getAuthenticationFactors()
        let p = _selectAuthenticationFactor(factors: factors)
        return p.then { factor in
            try op.requestCode(factor: factor)
        }.then { factor in
            self._getTwoFactorCode(factor: factor)
        }.then { code in
            try op.resolveCode(code: code)
        }.then { _ in
            try op.call()
        }.then { next in
            try self.resolveTwoFactor(op: next)
        }
    }

    func checkTwoFactorConfig(session: Session, expected: [String: Any]) throws {
        var config = try session.getTwoFactorConfig()
        for (key, value) in expected {
            if value is Bool {
                XCTAssert(config![key] as! Bool == value as! Bool)
            } else {
                XCTAssert(config![key] as! String == value as! String)
            }
        }
    }

    func doTwoFactor(op: TwoFactorCall) throws {
        let ex = expectation(description: "")
        let p = try self.resolveTwoFactor(op: op)
        _ = when(fulfilled: [p]).done { _ in ex.fulfill(); }
        waitForExpectations(timeout: 5, handler: nil)
    }

    func testTwoFactor() throws {
        let session : Session = try self.doLogin(network: Network.LocalTest)

        let allFactors: [String: String] = [
            "email": "foo@bar.com",
            "sms": "12345678",
            "phone": "12345678",
            "gauth": ""
        ]

        var expectedConfig: [String: Any] = [:]

        for (factor, data) in allFactors {
            try doTwoFactor(op: try session.disableTwoFactor(factor: factor))
            expectedConfig[factor] = false
            try checkTwoFactorConfig(session: session, expected: expectedConfig)
        }

        try doTwoFactor(op: try session.setEmail(email: "foo@bar.com"))
        expectedConfig["email_confirmed"] = true
        expectedConfig["email_addr"] = "foo@bar.com"
        try checkTwoFactorConfig(session: session, expected: expectedConfig)

        for (factor, data) in allFactors {
            try doTwoFactor(op: try session.enableTwoFactor(factor: factor, data: data))
            expectedConfig[factor] = true
            try checkTwoFactorConfig(session: session, expected: expectedConfig)
        }

        for (factor, data) in allFactors {
            try doTwoFactor(op: try session.disableTwoFactor(factor: factor))
            expectedConfig[factor] = false
            try checkTwoFactorConfig(session: session, expected: expectedConfig)
        }
    }

    func testGetTxListWrap() {
        do {
            let session : Session = try self.doLogin(network: Network.TestNet)

            let ex = expectation(description: "")

            let p1 = wrap {
                return try session.getTransactions(subaccount: 0)
            }.done { (txs: [Transaction]?) in
                if let l = txs {
                    for o in l {
                        let _ = try! o.toJSON()
                    }
                }
            }
            let p2 = wrap {
                try session.getBalance(subaccount: 0, numConfs: 0)
            }.done { (balance: [String: Any]?) in }

            _ = when(fulfilled: p1, p2).done { _, _ in ex.fulfill(); }
            waitForExpectations(timeout: 1, handler: nil)
        }
        catch {
            XCTAssert(false)
        }
    }

    func testGetTxListRetry() {
        do {
            let session : Session = try self.doLogin(network: Network.LocalTest)

            let ex = expectation(description: "")

            let p1 = wrap {
                return try session.getTransactions(subaccount: 0)
            }.done { (txs: [Transaction]?) in }
            let p2 = wrap {
                return try session.getBalance(subaccount: 0, numConfs: 0)
            }.done { (balance: [String: Any]?) in }

            _ = when(fulfilled: p1, p2).done { _, _ in ex.fulfill(); }
            waitForExpectations(timeout: 15, handler: nil)
        }
        catch {
            XCTAssert(false)
        }
    }
}

extension GreenAddressTests {
    static var allTests : [(String, (GreenAddressTests) -> () throws -> Void)] {
        return [
            ("testTwoFactor", testTwoFactor),
            ("testGetTxListWrap", testGetTxListWrap),
            ("testGetTxListRetry", testGetTxListRetry)
        ]
    }
}
