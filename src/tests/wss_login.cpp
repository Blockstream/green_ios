#include <iostream>

#include <autobahn/autobahn.hpp>

#include "session.hpp"

const std::string DEFAULT_ENDPOINT("ws://localhost:8080/v2/ws");

int main(int argc, char** argv)
{
    try {
        ga::sdk::session session;
        session.connect(DEFAULT_ENDPOINT, true);
        session.register_user("ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive spike pond industry time hero trim verb mammal asthma");
        session.login("ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive spike pond industry time hero trim verb mammal asthma");
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
