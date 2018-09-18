#include <chrono>
#include <condition_variable>
#include <iostream>
#include <thread>

using namespace std::chrono_literals;

#include "argparser.h"
#include "include/session.hpp"

const std::string DEFAULT_TOPIC("com.greenaddress.blocks");

int main(int argc, char** argv)
{
    using namespace ga;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    std::mutex mtx;
    std::condition_variable cv;

    try {
        sdk::session session;
        session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network());
        session.subscribe(DEFAULT_TOPIC, [&](const std::string& event) {
            std::cerr << event << std::endl;
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
