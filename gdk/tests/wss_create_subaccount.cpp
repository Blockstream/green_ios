#include <iostream>

#include "argparser.h"

#include "include/session.hpp"
#include "utils.hpp"

namespace {
static const std::string DEFAULT_MNEMONIC(
    "dilemma into virus stadium barrel undo shift echo nice flag toss little warm "
    "rubber carpet prize fitness debate february raise sample identify rail steak");
}

int main(int argc, char** argv)
{
    using namespace ga;

    auto&& assert_account_exists = [](const std::string& name, const auto& subaccounts) {
        GA_SDK_RUNTIME_ASSERT(std::any_of(
            std::begin(subaccounts), std::end(subaccounts), [name](const auto& acc) { return acc["name"] == name; }));
    };

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        const bool debug = options->quiet == 0;

        const std::string name_1{ get_random_string() };
        const std::string name_2{ get_random_string() };
        {
            sdk::session session;
            session.connect(sdk::network_parameters::get(options->network), debug);
            session.register_user(DEFAULT_MNEMONIC);
            session.login(DEFAULT_MNEMONIC);

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

            // Make sure we can generate valid addresses for both subaccount types
            const uint32_t sa1_pointer = sa1["pointer"];
            const auto address1 = session.get_receive_address(sa1_pointer);
            GA_SDK_RUNTIME_ASSERT(address1["address"] != "");

            const uint32_t sa2_pointer = sa2["pointer"];
            const auto address2 = session.get_receive_address(sa2_pointer);
            GA_SDK_RUNTIME_ASSERT(address2["address"] != "");
        }

        {
            sdk::session session;
            session.connect(sdk::network_parameters::get(options->network), debug);
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
