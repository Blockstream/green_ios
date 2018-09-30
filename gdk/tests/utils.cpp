#include "utils.hpp"

struct GA_session* create_new_wallet(struct options* options)
{
    GA_SDK_RUNTIME_ASSERT(!options->testnet); // Only for testing locally

    char* mnemonic = NULL;
    GA_SDK_RUNTIME_ASSERT(GA_generate_mnemonic("en", &mnemonic) == GA_OK);

    struct GA_session* session = NULL;
    GA_SDK_RUNTIME_ASSERT(GA_create_session(&session) == GA_OK);

    GA_SDK_RUNTIME_ASSERT(GA_connect(session, GA_NETWORK_LOCALTEST, options->quiet == 0) == GA_OK);
    GA_SDK_RUNTIME_ASSERT(GA_register_user(session, mnemonic) == GA_OK);
    GA_SDK_RUNTIME_ASSERT(GA_login(session, mnemonic) == GA_OK);
    GA_destroy_string(mnemonic);
    return session;
}
