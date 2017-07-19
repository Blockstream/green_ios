import GA

var session : Session = try Session()

let mnemonic: String = try generateMnemonic(lang: "en")

try session.connect(network: Network.TestNet)
try session.registerUser(mnemonic: mnemonic)
try session.login(mnemonic: mnemonic)
