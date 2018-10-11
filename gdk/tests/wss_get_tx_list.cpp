#include <chrono>
#include <iostream>

#include "argparser.h"
#include "include/session.hpp"

const std::string DEFAULT_MNEMONIC("tragic transfer mesh camera fish model bleak lumber never capital animal era "
                                   "coffee shift flame across pitch pipe shiver castle crawl noble obtain response");

int main(int argc, char** argv)
{
    using namespace std::chrono;
    using namespace ga;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        const bool debug = options->quiet == 0;
        sdk::session session;
        session.connect(options->network, std::string(), false, debug);
        session.register_user(DEFAULT_MNEMONIC);
        session.login(DEFAULT_MNEMONIC);

        const auto txs = session.get_transactions(0, 0);
        const uint32_t next_page_id = txs["next_page_id"];
        (void)next_page_id;

        const auto balance = session.get_balance(0, 0);
        session.get_enabled_twofactor_methods();
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
