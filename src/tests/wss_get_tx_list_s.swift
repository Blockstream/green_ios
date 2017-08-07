import Foundation
import GreenAddress

let DEFAULT_MNEMONIC: String = "tragic transfer mesh camera fish model bleak lumber never capital animal era " +
                               "coffee shift flame across pitch pipe shiver castle crawl noble obtain response"

var session : Session = try Session()

try session.connect(network: Network.TestNet, debug: true)
try session.registerUser(mnemonic: DEFAULT_MNEMONIC)
try session.login(mnemonic: DEFAULT_MNEMONIC)

let txs: [Transaction]? = try session.getTxList(begin: Date(timeIntervalSinceNow: -24*3600*28), end: Date(), subaccount: 0)
if let t = txs {
    for tx in t {
        let view = try! tx.getView()
        let amount = try! view.getValue()
        print(amount)
    }
}


let balance: [String: Any]? = try session.getBalance(numConfs: 0)
print(balance!)
