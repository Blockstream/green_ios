import Foundation

import ga.sdk

let DEFAULT_MNEMONIC
    = "believe roast zen poorer tax chicken snap calm override french banner salmon bird sad smart "
let DEFAULT_USER_AGENT = "[sw]"

var session : OpaquePointer?
var ret : Int32

ret = GA_create_session(&session)

ret = GA_connect(session, GA_NETWORK_TESTNET, 0)
ret = GA_register_user(session, DEFAULT_MNEMONIC)
ret = GA_login(session, DEFAULT_MNEMONIC)

GA_destroy_session(session)

exit(ret)
