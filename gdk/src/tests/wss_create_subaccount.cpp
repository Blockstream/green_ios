#include <iostream>

#include "argparser.h"

#include "src/assertion.hpp"
#include "src/session.hpp"
#include "src/utils.hpp"

namespace {
const std::string DEFAULT_MNEMONIC(
    "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive "
    "spike pond industry time hero trim verb mammal asthma");
}

int main(int argc, char** argv)
{
    using namespace ga;

    auto&& generate_name = [] { return sdk::hex_from_bytes(sdk::get_random_bytes<8>()); };
    auto&& assert_account_exists = [](const std::string& name, const auto& subaccounts) {
        GA_SDK_RUNTIME_ASSERT(std::any_of(std::begin(subaccounts), std::end(subaccounts),
            [name](const auto& acc) { return acc.template get<std::string>("name") == name; }));
    };

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        sdk::session session;
        session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
        session.register_user(DEFAULT_MNEMONIC);
        session.login(DEFAULT_MNEMONIC);

        const std::string name_1{ generate_name() };
        const std::string name_2{ generate_name() };
        {
            session.create_subaccount(sdk::subaccount_type::_2of2, name_1);
            session.create_subaccount(sdk::subaccount_type::_2of3, name_2);

            const auto subaccounts = session.get_subaccounts();
            assert_account_exists(name_1, subaccounts);
            assert_account_exists(name_2, subaccounts);
        }

        {
            const auto login_data = session.login(DEFAULT_MNEMONIC);
            const auto subaccounts = login_data.get_subaccounts();
            assert_account_exists(name_1, subaccounts);
            assert_account_exists(name_2, subaccounts);
        }
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
