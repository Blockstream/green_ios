#include <iostream>

#include "argparser.h"
#include "include/assertion.hpp"
#include "include/utils.hpp"

using namespace ga;

const std::string recipient("2Mwh2aUHBT2TNAkTdCZXicgWYwVt7mU6QHz");

int main(int argc, char** argv)
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    try {
        auto uri_elements = sdk::parse_bitcoin_uri("bitcoin:" + recipient);
        GA_SDK_RUNTIME_ASSERT(uri_elements["recipient"] == recipient);
        uri_elements = sdk::parse_bitcoin_uri("bitcoin:" + recipient + "?amount=0.001");
        GA_SDK_RUNTIME_ASSERT(recipient == uri_elements["recipient"]);
        GA_SDK_RUNTIME_ASSERT(uri_elements["amount"] == "0.001");
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
