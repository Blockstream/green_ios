#include <iostream>

#include "argparser.h"

#include "include/session.hpp"
#include "src/exception.hpp"
#include "utils.hpp"

int main(int argc, char** argv)
{
    using namespace ga;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        const bool debug = options->quiet == 0;
        nlohmann::json pin_info;
        std::string username = get_random_string();

        {
            sdk::session* session = reinterpret_cast<sdk::session*>(create_new_wallet(options));
            // TODO GA_SDK_RUNTIME_ASSERT(result.get<bool>("first_login"));
            pin_info = session->set_pin(session->get_mnemonic_passphrase(std::string()), "0000", "default");
            GA_SDK_RUNTIME_ASSERT(session->set_watch_only(username, "password"));
            const auto address = session->get_receive_address(0);
            GA_SDK_RUNTIME_ASSERT(address["address"] != "");
            delete session;
        }

        {
            sdk::session session;
            session.connect(sdk::network_parameters::get(options->network), debug);
            session.login_watch_only(username, "password");
            const auto address = session.get_receive_address(0);
            std::cerr << "address: " << address["address"] << std::endl;
        }

        {
            sdk::session session;
            session.connect(sdk::network_parameters::get(options->network), debug);
            assert_throws<ga::sdk::login_error>([&] { session.login("0001", pin_info); });
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
