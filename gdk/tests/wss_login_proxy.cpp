#include <iostream>

#include "argparser.h"

#include "include/assertion.hpp"
#include "include/session.hpp"

const std::string DEFAULT_MNEMONIC(
    "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive "
    "spike pond industry time hero trim verb mammal asthma");

int main(int argc, char** argv)
{
    using namespace ga;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        sdk::session session;
        try {
            session.connect(options->testnet ? sdk::make_testnet_network("socks5://localhost")
                                             : sdk::make_localtest_network("socks5://localhost"),
                true);
        } catch (const std::exception&) {
            if (options->testnet == 0) {
                std::cerr << "Skipping test (requires testnet or local environment w/proxy)" << std::endl;
                return 0;
            }
            throw;
        }
        session.register_user(DEFAULT_MNEMONIC);
        session.login(DEFAULT_MNEMONIC);
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
