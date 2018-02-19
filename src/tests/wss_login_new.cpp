#include <iostream>

#include <wally_bip39.h>

#include "argparser.h"

#include "assertion.hpp"
#include "session.hpp"
#include "utils.h"

int main(int argc, char** argv)
{
    using namespace ga;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        struct words* w;
        GA_SDK_RUNTIME_ASSERT(bip39_get_wordlist("en", &w) == WALLY_OK);

        char* m;
        GA_SDK_RUNTIME_ASSERT(bip39_mnemonic_from_bytes(w, sdk::get_random_bytes<32>().data(), 32, &m) == WALLY_OK);
        sdk::wally_string_ptr mnemonic(m, &wally_free_string);

        sdk::pin_info p;
        sdk::wally_string_ptr username = sdk::hex_from_bytes(sdk::get_random_bytes<8>());

        {
            sdk::session session;
            session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
            session.register_user(mnemonic.get());
            auto result = session.login(mnemonic.get());
            GA_SDK_RUNTIME_ASSERT(result.get<bool>("first_login"));
            p = session.set_pin(mnemonic.get(), "0000", "default");
            GA_SDK_RUNTIME_ASSERT(session.set_watch_only(username.get(), "password"));
        }

        {
            sdk::session session;
            session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
            auto result = session.login_watch_only(username.get(), "password");
        }

        {
            sdk::session session;
            session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
            auto result = session.login("0000", std::make_pair(p["pin_identifier"], p["secret"]));
            GA_SDK_RUNTIME_ASSERT(result.get<bool>("first_login") == false);
            GA_SDK_RUNTIME_ASSERT(session.remove_account());
        }
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
