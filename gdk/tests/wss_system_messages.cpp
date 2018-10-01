#include <iostream>

#include "argparser.h"
#include "utils.hpp"

#include "include/assertion.hpp"
#include "include/session.hpp"

const std::string DEFAULT_MNEMONIC("reopen danger sadness twenty move hire milk rally wing nature group correct tissue "
                                   "prefer scale scatter love resource around parade citizen topic consider exchange");

void assert_ack_throws(ga::sdk::session& session, const std::string& message)
{
    assert_throws<std::runtime_error>([&]() { session.ack_system_message(message); });
}

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

        while (!session.get_system_message().empty()) {
            const auto message = session.get_system_message();
            assert_ack_throws(session, message + "X"); // Wrong text
            session.ack_system_message(message);
            assert_ack_throws(session, message); // Already acked
        }
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
