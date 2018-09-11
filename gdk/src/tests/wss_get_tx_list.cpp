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

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        sdk::session session;
        session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
        session.register_user(DEFAULT_MNEMONIC);
        session.login(DEFAULT_MNEMONIC);

        const auto txs = session.get_transactions(0, 0);
        const uint32_t next_page_id = txs["next_page_id"];
        (void)next_page_id;

#if 0
        for (auto&& tx : txs) {
            sdk::tx t;
            t = tx;
        }
#endif

        const auto balance = session.get_balance(0, 0);
        const auto twofactor_config = session.get_twofactor_config();
        const std::string gauth_url = twofactor_config["gauth_url"];
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
