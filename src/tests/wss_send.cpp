#include <iostream>
#include <string>
#include <vector>

#include "argparser.h"

#include "assertion.hpp"
#include "http_jsonrpc_interface.hpp"
#include "session.hpp"

namespace {
const std::string DEFAULT_MNEMONIC_1(
    "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive "
    "spike pond industry time hero trim verb mammal asthma");

const std::string DEFAULT_MNEMONIC_2(
    "ignore roast anger enrich income pork snap busy final dutch banner lobster bird unhappy naive "
    "spike pond industry time hero trim verb reptile asthma");

const std::string GENERATE_SINGLE_BLOCK_REQUEST(
    R"rawlit({"jsonrpc": "1.0", "id":"generate", "method": "generate", "params": [1] })rawlit");

ga::sdk::receive_address login_and_get_receive_address(
    ga::sdk::session& session, const std::string& mnemonic, bool testnet)
{
    session.connect(testnet ? ga::sdk::make_testnet_network() : ga::sdk::make_localtest_network(), true);
    session.register_user(mnemonic);
    session.login(mnemonic);
    return session.get_receive_address(ga::sdk::address_type::p2wsh);
}
}

int main(int argc, char** argv)
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        ga::sdk::session session_1;
        ga::sdk::session session_2;
        const auto address_1 = login_and_get_receive_address(session_1, DEFAULT_MNEMONIC_1, options->testnet);
        const auto address_2 = login_and_get_receive_address(session_2, DEFAULT_MNEMONIC_2, options->testnet);

        ga::sdk::http_jsonrpc_client rpc;
        const auto send_request = rpc.make_send_to_address(address_1.get<std::string>("p2wsh"), "2");
        std::cerr << "p2sh " << send_request << std::endl;
        // rpc.sync_post("127.0.0.1", "19001", send_request);
        // rpc.sync_post("127.0.0.1", "19001", GENERATE_SINGLE_BLOCK_REQUEST);

        std::cerr << address_2.get<std::string>("p2wsh") << std::endl;
        session_1.send({ { address_2.get<std::string>("p2wsh"), 100000 } }, 1000);
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
