#include <chrono>
#include <ctime>
#include <iostream>

#include "argparser.h"
#include "src/assertion.hpp"

#include "src/session.hpp"

const std::string DEFAULT_MNEMONIC("tragic transfer mesh camera fish model bleak lumber never capital animal era "
                                   "coffee shift flame across pitch pipe shiver castle crawl noble obtain response");

int main(int argc, char** argv)
{
    using namespace std::chrono;
    using namespace ga;
    using namespace ga::sdk::literals;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        sdk::session session;
        session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
        session.register_user(DEFAULT_MNEMONIC);
        session.login(DEFAULT_MNEMONIC);

        const auto txs = session.get_tx_list(0, std::make_pair(0, 0), '+'_ts, 0, "");
        GA_SDK_RUNTIME_ASSERT(txs.get<std::string>("fiat_currency") == "USD");

        for (auto&& tx : txs) {
            sdk::tx t;
            t = tx;
        }

        const auto balance = session.get_balance(0);
        const auto twofactor_config = session.get_twofactor_config();
        const auto gauth_url = twofactor_config.get<std::string>("gauth_url");
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
