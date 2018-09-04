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
        GA_SDK_RUNTIME_ASSERT(std::any_of(
            std::begin(subaccounts), std::end(subaccounts), [name](const auto& acc) { return acc["name"] == name; }));
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
            const nlohmann::json sa1 = session.create_subaccount({ { "name", name_1 }, { "type", "2of2" } });
            GA_SDK_RUNTIME_ASSERT(sa1["name"] == name_1);
            GA_SDK_RUNTIME_ASSERT(sa1["type"] == "2of2");
            const nlohmann::json sa2 = session.create_subaccount({ { "name", name_2 }, { "type", "2of3" } });
            GA_SDK_RUNTIME_ASSERT(sa2["name"] == name_2);
            GA_SDK_RUNTIME_ASSERT(sa2["type"] == "2of3");
            const std::string foo = sa2.dump();
            GA_SDK_RUNTIME_ASSERT(!sa2["recovery_mnemonic"].empty());
            GA_SDK_RUNTIME_ASSERT(!sa2["recovery_xpub"].empty());

            const auto subaccounts = session.get_subaccounts();
            assert_account_exists(name_1, subaccounts);
            assert_account_exists(name_2, subaccounts);
        }

        {
            session.login(DEFAULT_MNEMONIC);
            const auto subaccounts = session.get_subaccounts();
            assert_account_exists(name_1, subaccounts);
            assert_account_exists(name_2, subaccounts);
        }
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
