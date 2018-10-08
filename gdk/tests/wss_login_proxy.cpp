#include <iostream>

#include "argparser.h"

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
        const bool debug = options->quiet == 0;
        sdk::session session;
        try {
            session.connect(sdk::network_parameters::get(options->network, "socks5://localhost"), debug);
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
