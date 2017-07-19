import Foundation
import GA

let DEFAULT_MNEMONIC
    = "believe roast zen poorer tax chicken snap calm override french banner salmon bird sad smart "

var session : Session = try Session()

try session.connect(network: Network.TestNet)
try session.registerUser(mnemonic: DEFAULT_MNEMONIC)
try session.login(mnemonic: DEFAULT_MNEMONIC)

let txs: [String: Any]? = try session.getTxList(begin: Date(), end: Date(), subaccount: 0)
