#include <iostream>

#include "argparser.h"

#include "include/session.hpp"

const std::string DEFAULT_MNEMONIC("scrub fabric reason comic sketch aerobic feel dress quick frog air capable october "
                                   "avoid rail tent arctic gym cliff piece bitter cigar mutual cage");

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
        session.change_settings_privacy_send_me(sdk::privacy_send_me::private_);
        session.change_settings_privacy_show_as_sender(sdk::privacy_show_as_sender::public_);
        session.change_settings_tx_limits(false, 0, {});
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
