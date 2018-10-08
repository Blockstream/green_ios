#include <chrono>
#include <condition_variable>
#include <iostream>
#include <thread>

using namespace std::chrono_literals;

#include "argparser.h"
#include "include/session.hpp"

namespace {
static const std::string DEFAULT_MNEMONIC(
    "hello sunny fantasy opinion voyage screen inspire wonder account moon gun quantum rug allow random copper witness "
    "exchange relief quarter laugh junior danger advance");

static std::mutex mtx;
static std::condition_variable cv;

static void on_notification(void* context, const GA_json* details_c)
{
    (void)context;
    if (details_c) {
        const nlohmann::json& details = *(reinterpret_cast<const nlohmann::json*>(details_c));
        std::cerr << details.dump() << std::endl;
        cv.notify_one();
    }
}
} // namespace

int main(int argc, char** argv)
{
    using namespace ga;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    try {
        const bool debug = options->quiet == 0;
        sdk::session session;
        session.set_notification_handler(on_notification, nullptr);
        session.connect(sdk::network_parameters::get(options->network), debug);
        session.register_user(DEFAULT_MNEMONIC);
        session.login(DEFAULT_MNEMONIC);

        const bool manual_test = false; // Change to true for manual testing
        if (manual_test) {
            std::cerr << "run\ncli sendtoaddress " << session.get_receive_address(0)["address"] << " 1.0\n"
                      << "to receive a transaction notification" << std::endl;
        }

        std::unique_lock<std::mutex> lck(mtx);
        cv.wait_for(lck, manual_test ? 120s : 10s);
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
