#include <chrono>
#include <ctime>
#include <iostream>

#include "argparser.h"
#include "assertion.hpp"

#include "session.hpp"

const std::string DEFAULT_MNEMONIC(
    "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive "
    "spike pond industry time hero trim verb mammal asthma");

int main(int argc, char** argv)
{
    using namespace std::chrono;
    using namespace ga::sdk::literals;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        ga::sdk::session session;
        session.connect(options->testnet ? ga::sdk::make_testnet_network() : ga::sdk::make_localtest_network(), true);
        session.register_user(DEFAULT_MNEMONIC);
        session.login(DEFAULT_MNEMONIC);

        using days = std::chrono::duration<int, std::ratio<24 * 3600>>;

        const auto now = std::chrono::system_clock::now();
        const auto now_28_days_before = now - days(28);

        const auto txs = session.get_tx_list(
            std::make_pair(system_clock::to_time_t(now_28_days_before), system_clock::to_time_t(now)), 0, '+'_ts, 0,
            "");
        GA_SDK_RUNTIME_ASSERT(txs.get<std::string>("fiat_currency") == "USD");
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
