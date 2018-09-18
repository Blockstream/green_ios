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
        session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
        session.register_user(DEFAULT_MNEMONIC);
        session.login(DEFAULT_MNEMONIC);
        // TODO GA_SDK_RUNTIME_ASSERT(result.get<int>("min_fee") == 1000);
        if (options->testnet) {
            auto r = session.get_available_currencies();
            std::vector<std::string> v = r["per_exchange"]["LOCALBTC"];
            GA_SDK_RUNTIME_ASSERT(std::find(v.begin(), v.end(), "GBP") != v.end());
        }
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
