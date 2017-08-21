import XCTest
import Foundation

import PromiseKit

@testable import GreenAddress

class GreenAddressTests : XCTestCase {

    let DEFAULT_MNEMONIC: String = "tragic transfer mesh camera fish model bleak lumber never capital animal era " +
                                   "coffee shift flame across pitch pipe shiver castle crawl noble obtain response"

    func testGetTxList() {
        do {
            var session : Session = try Session()

            let ex = expectation(description: "")

            let p1 = wrap { try session.connect(network: Network.TestNet, debug: true) }
            let p2 = wrap { try session.registerUser(mnemonic: DEFAULT_MNEMONIC) }
            let p3 = wrap { try session.login(mnemonic: DEFAULT_MNEMONIC) }
            let p4 = wrap { () -> [Transaction]? in
                return try session.getTxList(begin: Date(timeIntervalSinceNow: -24*3600*28), end: Date(), subaccount: 0)
            }.then { (txs: [Transaction]?) -> Void in
                if let t = txs {
                    for tx in t {
                        let view = try! tx.getView()
                        let amount = try! view.getValue()
                        print(amount)
                    }
                }
            }
            let p5 = wrap {
                try session.getBalance(numConfs: 0)
            }.then { (balance: [String: Any]?) -> Void in
                print(balance)
            }

            when(fulfilled: [p1, p2, p3, p4, p5]).then { ex.fulfill(); }
            waitForExpectations(timeout: 1, handler: nil)
        }
        catch {
            XCTAssert(false)
        }
    }
}

extension GreenAddressTests {
    static var allTests : [(String, (GreenAddressTests) -> () throws -> Void)] {
        return [
            ("testGetTxList", testGetTxList)
        ]
    }
}
