#include <iostream>

#include "argparser.h"

#include "src/assertion.hpp"
#include "src/session.hpp"
#include "src/utils.hpp"

int main(int argc, char** argv)
{
    using namespace ga;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        const auto mnemonic = sdk::mnemonic_from_bytes(sdk::get_random_bytes<32>().data(), 32, "en");

        sdk::pin_info p;
        std::string username = sdk::hex_from_bytes(sdk::get_random_bytes<8>());

        {
            sdk::session session;
            session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
            session.register_user(mnemonic);
            auto result = session.login(mnemonic);
            GA_SDK_RUNTIME_ASSERT(result.get<bool>("first_login"));
            p = session.set_pin(mnemonic, "0000", "default");
            GA_SDK_RUNTIME_ASSERT(session.set_watch_only(username, "password"));
            const auto address = session.get_receive_address(0, sdk::address_type::p2sh);
            GA_SDK_RUNTIME_ASSERT(address.get_address() != "");
        }

        {
            sdk::session session;
            session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
            auto result = session.login_watch_only(username, "password");
            const auto address = session.get_receive_address(0, sdk::address_type::p2sh);
            std::cerr << "address: " << address.get_address() << std::endl;
        }

        {
            sdk::session session;
            session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
            auto result = session.login("0000", std::make_pair(p["pin_identifier"], p["secret"]));
            GA_SDK_RUNTIME_ASSERT(result.get<bool>("first_login") == false);
            GA_SDK_RUNTIME_ASSERT(session.remove_account());
        }
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
