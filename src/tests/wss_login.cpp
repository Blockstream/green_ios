#include <iostream>

#include "session.hpp"

const std::string DEFAULT_MNEMONIC(
    "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive "
    "spike pond industry time hero trim verb mammal asthma");
const std::string DEFAULT_USER_AGENT("[sw]");

int main(int argc, char** argv)
{
    try {
        ga::sdk::session session;
        session.connect(ga::sdk::make_localtest_network(), true);
        session.register_user(DEFAULT_MNEMONIC, DEFAULT_USER_AGENT);
        session.login(DEFAULT_MNEMONIC, DEFAULT_USER_AGENT);
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
