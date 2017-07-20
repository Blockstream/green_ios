import GreenAddress

let DEFAULT_MNEMONIC: String = "tragic transfer mesh camera fish model bleak lumber never capital animal era " +
                               "coffee shift flame across pitch pipe shiver castle crawl noble obtain response"

var session : Session = try Session()

try session.connect(network: Network.TestNet)
try session.registerUser(mnemonic: DEFAULT_MNEMONIC)
try session.login(mnemonic: DEFAULT_MNEMONIC)
