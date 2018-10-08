#include <iostream>

#include "argparser.h"
#include "utils.hpp"

#include "include/session.hpp"

void assert_register_user_fails(ga::sdk::session& session, const std::string& mnemonic)
{
    assert_throws<std::runtime_error>([&]() { session.register_user(mnemonic); });
}

int main(int argc, char** argv)
{
    using namespace ga;

    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        const bool debug = options->quiet == 0;
        sdk::session session;
        session.connect(sdk::network_parameters::get(options->network), debug);
        assert_register_user_fails(session, "Invalid");

        // Valid checksum but too short (<12 words)
        assert_register_user_fails(session, "husband design sense");
        assert_register_user_fails(session, "verify limit orphan bag expand brand square smart behind");

        // Not a multiple of 3 words in length
        assert_register_user_fails(session, "verify limit orphan bag expand brand square smart behind smart");
        assert_register_user_fails(session, "verify limit orphan bag expand brand square smart behind smart limit");
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
