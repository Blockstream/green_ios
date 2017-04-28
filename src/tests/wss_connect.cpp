#include <iostream>

#include "session.hpp"

int main(int argc, char** argv)
{
    try {
        ga::sdk::session session;
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }

    return 0;
}
