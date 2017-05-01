#include <iostream>

#include "session.hpp"

const std::string DEFAULT_ENDPOINT("ws://localhost:8080/v2/ws");

int main(int argc, char** argv)
{
    try {
        ga::sdk::session session;
        session.connect(DEFAULT_ENDPOINT);
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }

    return 0;
}
