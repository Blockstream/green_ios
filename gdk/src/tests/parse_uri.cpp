#include <iostream>

#include "argparser.h"
#include "src/assertion.hpp"
#include "src/utils.hpp"

using namespace ga;

const std::string recipient("2Mwh2aUHBT2TNAkTdCZXicgWYwVt7mU6QHz");

int main(int argc, char** argv)
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    try {
        auto uri_elements = sdk::parse_bitcoin_uri("bitcoin:" + recipient);
        GA_SDK_RUNTIME_ASSERT(uri_elements.get<std::string>("recipient") == recipient);
        uri_elements = sdk::parse_bitcoin_uri("bitcoin:" + recipient + "?amount=0.001");
        GA_SDK_RUNTIME_ASSERT(uri_elements.get<std::string>("recipient") == recipient);
        GA_SDK_RUNTIME_ASSERT(uri_elements.get<std::string>("amount") == "0.001");
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
