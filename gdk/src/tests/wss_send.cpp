#include <iostream>
#include <string>
#include <vector>

#include "argparser.h"

#include "http_jsonrpc_interface.hpp"
#include "src/assertion.hpp"
#include "src/session.hpp"

using namespace ga;

namespace {
const std::string DEFAULT_MNEMONIC_1(
    "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive "
    "spike pond industry time hero trim verb mammal asthma");

const std::string DEFAULT_MNEMONIC_2(
    "sustain pumpkin scrub about voyage laptop script engine upset spoil nerve chicken tackle analyst "
    "actress gauge second pink hero rack warm detail sleep dawn");

const std::string GENERATE_SINGLE_BLOCK_REQUEST(
    R"rawlit({"jsonrpc": "1.0", "id":"generate", "method": "generate", "params": [1] })rawlit");

nlohmann::json login_and_get_receive_address(sdk::session& session, const std::string& mnemonic, bool testnet)
{
    session.connect(testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), true);
    session.register_user(mnemonic);
    session.login(mnemonic);
    return session.get_receive_address(0, sdk::address_type::p2sh);
}
} // namespace

int main(int argc, char** argv)
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        sdk::session session_1;
        sdk::session session_2;
        const auto address_1 = login_and_get_receive_address(session_1, DEFAULT_MNEMONIC_1, options->testnet != 0);
        const auto address_2 = login_and_get_receive_address(session_2, DEFAULT_MNEMONIC_2, options->testnet != 0);

        sdk::http_jsonrpc_client rpc;
        const auto send_request = rpc.make_send_to_address(address_1["address"], "2");
        std::cerr << "p2sh " << send_request << std::endl;
        rpc.sync_post("127.0.0.1", "19001", send_request);
        rpc.sync_post("127.0.0.1", "19001", GENERATE_SINGLE_BLOCK_REQUEST);

        std::cerr << address_2["address"] << std::endl;
        const std::string addr = address_2["address"];
#if 0
        // Sample regtest addresses for debugging
        const std::string addr{"mnvL3wwo8sPCkHbkdq3Lzc2Y4NhguNKnyk"}; // P2PKH
        const std::string addr{"bcrt1q0wamd2z3yxrwa3c96knlfdjntj6hhngweuj4vv"}; // P2WPKH
        const std::string addr{ "bcrt1qkk3vjcjsvy3kd6389lavdkt5f2h5k3d2ekt25l8uhyc7uw64sfvsk5excw" }; // P2WSH
#endif
        session_1.send(0, { { addr, sdk::amount{ 100000 } } }, sdk::amount{ 1000 }, false, nlohmann::json());
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
