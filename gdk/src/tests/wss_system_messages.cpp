#include <iostream>

#include "argparser.h"
#include "utils.hpp"

#include "src/assertion.hpp"
#include "src/session.hpp"

const std::string DEFAULT_MNEMONIC(
    "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive "
    "spike pond industry time hero trim verb mammal asthma");

void assert_ack_throws(ga::sdk::session& session, uint32_t system_message_id, const std::string& text)
{
    assert_throws<std::runtime_error>([&]() { session.ack_system_message(system_message_id, text); });
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
        const auto result = session.login(DEFAULT_MNEMONIC);
        auto system_message_id = result.get_with_default<uint32_t>("next_system_message_id", 0);
        while (system_message_id) {
            const auto message = session.get_system_message(system_message_id);
            const auto text = message.get<std::string>("message");
            assert_ack_throws(session, system_message_id, text + "X"); // Wrong text
            session.ack_system_message(system_message_id, text);
            assert_ack_throws(session, system_message_id, text); // Already acked
            system_message_id = message.get_with_default<uint32_t>("next_message_id", 0);
        }
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
