#include <iostream>

#include "argparser.h"

#include "include/assertion.hpp"
#include "include/session.hpp"

const std::string DEFAULT_MNEMONIC("dismiss chaos result march slow sock hybrid foster chest analyst blue decline "
                                   "alarm advance polar squeeze shy actress target satoshi sleep wage cruel tell");

int main(int argc, char** argv)
{
    using namespace ga;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        sdk::session session;
        session.connect(
            options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), options->quiet == 0);
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
