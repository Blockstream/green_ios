import XCTest
import Foundation

import PromiseKit

@testable import GreenAddress

class GreenAddressTests : XCTestCase {

    let DEFAULT_MNEMONIC: String = "tragic transfer mesh camera fish model bleak lumber never capital animal era " +
                                   "coffee shift flame across pitch pipe shiver castle crawl noble obtain response"

    func testGetTxListWrap() {
        do {
            let session : Session = try Session()

            let ex = expectation(description: "")

            let p1 = wrap { try session.connect(network: Network.TestNet, debug: true) }
            let p2 = wrap { try session.registerUser(mnemonic: self.DEFAULT_MNEMONIC) }
            let p3 = wrap { try session.login(mnemonic: self.DEFAULT_MNEMONIC) }
            let p4 = wrap {
                return try session.getTransactions(subaccount: 0)
            }.done { (txs: [Transaction]?) in
                if let l = txs {
                    for o in l {
                        let _ = try! o.toJSON()
                    }
                }
            }
            let p5 = wrap {
                try session.getBalance(numConfs: 0)
            }.done { (balance: [String: Any]?) in }

            _ = when(fulfilled: p1, p2, p3, p4, p5).done { _, _, _, _, _ in ex.fulfill(); }
            waitForExpectations(timeout: 1, handler: nil)
        }
        catch {
            XCTAssert(false)
        }
    }

    func testGetTxListRetry() {
        do {
            let session : Session = try Session()
            let network : Network = Network.LocalTest

            let ex = expectation(description: "")

            let p1 = retry(session: session, network: network) { wrap { try session.connect(network: network, debug: true) } }
            let p2 = retry(session: session, network: network) { wrap { try session.registerUser(mnemonic: self.DEFAULT_MNEMONIC) } }
            let p3 = wrap { try session.login(mnemonic: self.DEFAULT_MNEMONIC) }
            let p4 = wrap {
                return try session.getTransactions(subaccount: 0)
            }.done { (txs: [Transaction]?) in }
            let p5 = wrap {
                return try session.getBalance(numConfs: 0)
            }.done { (balance: [String: Any]?) in }

            _ = when(fulfilled: p1, p2, p3, p4, p5).done { _, _, _, _, _ in ex.fulfill(); }
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
            ("testGetTxListWrap", testGetTxListWrap),
            ("testGetTxListRetry", testGetTxListRetry)
        ]
    }
}
