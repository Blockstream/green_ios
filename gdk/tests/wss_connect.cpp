#include <iostream>

#include "argparser.h"

#include "include/session.hpp"

int main(int argc, char** argv)
{
    using namespace ga;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        const bool debug = options->quiet == 0;
        sdk::session session;
        session.connect(sdk::network_parameters::get(options->network), debug);
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }

    return 0;
}
