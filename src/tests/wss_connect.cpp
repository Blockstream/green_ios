#include <iostream>

#include "argparser.h"

#include "session.hpp"

int main(int argc, char** argv)
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        ga::sdk::session session;
        session.connect(options->testnet ? ga::sdk::make_testnet_network() : ga::sdk::make_localtest_network());
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }

    return 0;
}
