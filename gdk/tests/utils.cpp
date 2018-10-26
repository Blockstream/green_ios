#include "src/utils.hpp"
#include "src/boost_wrapper.hpp"
#include "src/ga_wally.hpp"
#include "utils.hpp"

struct GA_session* create_new_wallet(struct options* options)
{
    GA_SDK_RUNTIME_ASSERT(strcmp(options->network, "testnet")); // Only for testing locally

    char* mnemonic = NULL;
    GA_SDK_RUNTIME_ASSERT(GA_generate_mnemonic(&mnemonic) == GA_OK);

    struct GA_session* session = NULL;
    GA_SDK_RUNTIME_ASSERT(GA_create_session(&session) == GA_OK);

    const bool debug = options->quiet == 0;
    GA_SDK_RUNTIME_ASSERT(GA_connect(session, options->network, debug) == GA_OK);
    GA_SDK_RUNTIME_ASSERT(GA_register_user(session, mnemonic) == GA_OK);
    GA_SDK_RUNTIME_ASSERT(GA_login(session, mnemonic, "") == GA_OK);
    GA_destroy_string(mnemonic);
    return session;
}

std::string get_random_string() { return ga::sdk::hex_from_bytes(ga::sdk::get_random_bytes<32>()); }
