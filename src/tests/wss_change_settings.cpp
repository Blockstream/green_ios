#include <iostream>

#include "argparser.h"

#include "session.hpp"

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
        session.change_settings(sdk::settings::privacy_send_me, sdk::privacy_send_me::private_);
        session.change_settings(sdk::settings::privacy_show_as_sender, sdk::privacy_show_as_sender::public_);
        session.change_settings(
            sdk::settings::tx_limits, sdk::tx_limits::total, 0, sdk::tx_limits::per_tx, 0, sdk::tx_limits::is_fiat, 0);
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
