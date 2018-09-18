#include <iostream>

#include "argparser.h"

#include "include/assertion.hpp"
#include "include/session.hpp"
#include "include/utils.hpp"

int main(int argc, char** argv)
{
    using namespace ga;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        const auto mnemonic = sdk::mnemonic_from_bytes(sdk::get_random_bytes<32>().data(), 32, "en");

        nlohmann::json pin_info;
        std::string username = sdk::hex_from_bytes(sdk::get_random_bytes<8>());

        {
            sdk::session session;
            session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
            session.register_user(mnemonic);
            session.login(mnemonic);
            // TODO GA_SDK_RUNTIME_ASSERT(result.get<bool>("first_login"));
            pin_info = session.set_pin(mnemonic, "0000", "default");
            GA_SDK_RUNTIME_ASSERT(session.set_watch_only(username, "password"));
            const auto address = session.get_receive_address(0, sdk::address_type::p2sh);
            GA_SDK_RUNTIME_ASSERT(address["address"] != "");
        }

        {
            sdk::session session;
            session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
            session.login_watch_only(username, "password");
            const auto address = session.get_receive_address(0, sdk::address_type::p2sh);
            std::cerr << "address: " << address["address"] << std::endl;
        }

        {
            sdk::session session;
            session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
            session.login("0000", pin_info);
            // TODO GA_SDK_RUNTIME_ASSERT(result.get<bool>("first_login") == false);
            GA_SDK_RUNTIME_ASSERT(session.remove_account(nlohmann::json()));
        }
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
