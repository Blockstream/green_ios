#include <iostream>

#include "argparser.h"

#include "assertion.hpp"
#include "session.hpp"

const std::string DEFAULT_MNEMONIC(
    "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive "
    "spike pond industry time hero trim verb mammal asthma");

int main(int argc, char** argv)
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        ga::sdk::session session;
        session.connect(options->testnet ? ga::sdk::make_testnet_network() : ga::sdk::make_localtest_network(), true);
        session.register_user(DEFAULT_MNEMONIC);
        auto result = session.login(DEFAULT_MNEMONIC);
        GA_SDK_RUNTIME_ASSERT(result.get<int>("min_fee") == 1000);
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
