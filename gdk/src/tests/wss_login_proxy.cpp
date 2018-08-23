#include <iostream>

#include "argparser.h"

#include "src/assertion.hpp"
#include "src/session.hpp"

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
        session.connect(options->testnet ? sdk::make_testnet_network("socks5://localhost")
                                         : sdk::make_localtest_network("socks5://localhost"),
            true);
        session.register_user(DEFAULT_MNEMONIC);
        auto result = session.login(DEFAULT_MNEMONIC);
        GA_SDK_RUNTIME_ASSERT(result.get<bool>("appearance/use_segwit"));
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
