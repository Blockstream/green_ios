import Foundation

import ga.sdk

var session : OpaquePointer?
var ret : Int32
var mnemonic : UnsafeMutablePointer<Int8>?

ret = GA_generate_mnemonic("en", &mnemonic)

ret = GA_create_session(&session)

ret = GA_connect(session, GA_NETWORK_TESTNET, 0)
ret = GA_register_user(session, mnemonic)
ret = GA_login(session, mnemonic)

GA_destroy_session(session)

exit(ret)
