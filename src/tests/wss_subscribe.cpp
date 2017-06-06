#include <chrono>
#include <condition_variable>
#include <iostream>
#include <thread>

using namespace std::chrono_literals;

#include "argparser.h"
#include "session.hpp"

const std::string DEFAULT_TOPIC("com.greenaddress.blocks");

int main(int argc, char** argv)
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    std::mutex mtx;
    std::condition_variable cv;

    try {
        ga::sdk::session session;
        session.connect(options->testnet ? ga::sdk::make_testnet_network() : ga::sdk::make_localtest_network());
        session.subscribe(DEFAULT_TOPIC, [&](const autobahn::wamp_event& event) {
            using topic_type = std::unordered_map<std::string, size_t>;
            auto ev = event.argument<topic_type>(0);
            for (auto&& arg : ev) {
                std::cerr << arg.first << " " << arg.second << std::endl;
            }
            cv.notify_one();
        });

        std::unique_lock<std::mutex> lck(mtx);
        cv.wait_for(lck, 10s);
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
