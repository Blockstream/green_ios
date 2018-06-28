#include <iostream>

#include "argparser.h"

#include "assertion.hpp"
#include "session.hpp"

const std::string DEFAULT_MNEMONIC(
    "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive "
    "spike pond industry time hero trim verb mammal asthma");

template <typename T>
void assert_throws(T&& fn)
{
    bool threw = false;
    try
    {
        fn();
    }
    catch (const std::runtime_error& e)
    {
        threw = true;
    }
    GA_SDK_RUNTIME_ASSERT(threw);
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
        auto system_message_id = result.get_with_default<unsigned>("next_system_message_id", 0);
        while (system_message_id) {
            const auto message = session.get_system_message(system_message_id);
            const auto text = message.get<std::string>("message");
            assert_throws([&](){ session.ack_system_message(system_message_id, text + "X"); });
            session.ack_system_message(system_message_id, text);
            assert_throws([&](){ session.ack_system_message(system_message_id, text); });
            system_message_id = message.get_with_default<unsigned>("next_message_id", 0);
        }
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
