#include <iostream>

#include <wally_bip39.h>

#include "argparser.h"

#include "assertion.hpp"
#include "session.hpp"
#include "utils.h"

int main(int argc, char** argv)
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        const struct words* w;
        GA_SDK_RUNTIME_ASSERT(bip39_get_wordlist("en", &w) == WALLY_OK);

        char* mnemonic = nullptr;
        GA_SDK_RUNTIME_ASSERT(
            bip39_mnemonic_from_bytes(w, ga::sdk::get_random_bytes<32>().data(), 32, &mnemonic) == WALLY_OK);

        ga::sdk::session session;
        session.connect(options->testnet ? ga::sdk::make_testnet_network() : ga::sdk::make_localtest_network(), true);
        session.register_user(mnemonic);
        auto result = session.login(mnemonic);
        GA_SDK_RUNTIME_ASSERT(result.get<bool>("first_login"));
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
