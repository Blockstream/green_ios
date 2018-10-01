#include <iostream>
#include <string>
#include <vector>

#include "argparser.h"

#include "http_jsonrpc_interface.hpp"
#include "include/assertion.hpp"
#include "include/session.h"
#include "include/session.hpp"
#include "include/twofactor.h"

using namespace ga;

namespace {
const std::string DUMMY_CODE = "555555";

const std::string DEFAULT_MNEMONIC_1("infant earth modify pyramid hunt reopen write asthma middle during mechanic "
                                     "carry health chat plate wear cycle market knock number blur near permit core");

const std::string DEFAULT_MNEMONIC_2(
    "sustain pumpkin scrub about voyage laptop script engine upset spoil nerve chicken tackle analyst "
    "actress gauge second pink hero rack warm detail sleep dawn");

const std::string GENERATE_SINGLE_BLOCK_REQUEST(
    R"rawlit({"jsonrpc": "1.0", "id":"generate", "method": "generate", "params": [1] })rawlit");

void login(sdk::session& session, const std::string& mnemonic, struct options* options)
{
    const bool debug = options->quiet == 0;
    session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), debug);
    session.register_user(mnemonic);
    session.login(mnemonic);
}
} // namespace

int main(int argc, char** argv)
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);
    try {
        sdk::session sender;
        sdk::session receiver;

        login(sender, DEFAULT_MNEMONIC_1, options);
        login(receiver, DEFAULT_MNEMONIC_2, options);

        if (!options->testnet) {
            // On localtest, enable 2fa to test sending with 2fa enabled
            sender.get_twofactor_config();
            sender.enable_gauth(DUMMY_CODE, nlohmann::json());
        }

        const uint32_t num_confs = 1;
        nlohmann::json sender_utxos = sender.get_unspent_outputs(0, num_confs);

        if (sender_utxos.size() < 10u) {
            std::cerr << "Generating utxos for sending" << std::endl;

            // Give the sender some confirmed UTXOs to spend
            std::vector<std::pair<std::string, std::string>> addressees;
            for (size_t i = 0; i < 20u; ++i) {
                const std::string addr = sender.get_receive_address(0, sdk::address_type::default_)["address"];
                addressees.emplace_back(std::make_pair(addr, "0.5"));
            }
            sdk::http_jsonrpc_client rpc;
            const auto send_request = rpc.make_send_to_addressees(addressees);
            rpc.sync_post("127.0.0.1", "19001", send_request);

            rpc.sync_post("127.0.0.1", "19001", GENERATE_SINGLE_BLOCK_REQUEST);

            // FIXME: should really wait for the block notification here
            sender_utxos = sender.get_unspent_outputs(0, num_confs);
        }
        const size_t num_sender_utxos = sender_utxos.size();

        const std::string recv_addr = receiver.get_receive_address(0, sdk::address_type::default_)["address"];
#if 0
        // Sample regtest addresses for debugging
        const std::string recv_addr{ "mnvL3wwo8sPCkHbkdq3Lzc2Y4NhguNKnyk" }; // P2PKH
        const std::string recv_addr{ "bcrt1q0wamd2z3yxrwa3c96knlfdjntj6hhngweuj4vv" }; // P2WPKH
        const std::string recv_addr{ "bcrt1qkk3vjcjsvy3kd6389lavdkt5f2h5k3d2ekt25l8uhyc7uw64sfvsk5excw" }; // P2WSH
#endif
        const std::vector<nlohmann::json> addressees{ {
            { "address", recv_addr },
            { "satoshi", 100000 },
        } };

        // Create a tx to send. In a wallet this would be an iterative processes
        // as the user adjusts amounts etc.
        // Here we allow the create_transaction defaulting to add utxos for us
        nlohmann::json details = sender.create_transaction({ { "addressees", addressees }, { "fee_rate", 1000 } });
        // std::cerr << "initial: " << std::endl << details.dump() << std::endl << std::endl;

        // Make a note of our change address
        GA_SDK_RUNTIME_ASSERT(details.value("have_change", true));
        const std::string change_address = details["change_address"];

        // Simulate a user choosing another fee rate, adding a memo and using
        // coin control to select all utxos: the tx details are dynamically updated
        details["fee_rate"] = 1500;
        details["memo"] = "test memo";
        details["utxo_strategy"] = "manual";
        std::vector<size_t> used_utxos;
        for (size_t i = 0; i < num_sender_utxos; ++i) {
            used_utxos.emplace_back(i);
        }
        details["used_utxos"] = used_utxos;
        details = sender.create_transaction(details);
        GA_SDK_RUNTIME_ASSERT(details["used_utxos"].size() == used_utxos.size());
        // std::cerr << "manual: " << std::endl << details.dump() << std::endl << std::endl;

        // User reverts back to GDK's utxo selection algorithm
        details["utxo_strategy"] = "default";
        details = sender.create_transaction(details);
        GA_SDK_RUNTIME_ASSERT(details["used_utxos"].size() < used_utxos.size());
        // std::cerr << "default: " << std::endl << details.dump() << std::endl << std::endl;

        // Verify that the old change address was re-used
        GA_SDK_RUNTIME_ASSERT(change_address == details["change_address"]);

        // Send the transaction, signing it automatically
        nlohmann::json transaction;
        if (options->testnet) {
            transaction = sender.send(details, nlohmann::json());
        } else {
            // Test sending with 2fa enabled through the call interface
            struct GA_twofactor_call* call = nullptr;
            struct GA_session* sender_c = reinterpret_cast<struct GA_session*>(&sender);
            struct GA_json* details_c = reinterpret_cast<struct GA_json*>(&details);
            GA_SDK_RUNTIME_ASSERT(GA_send_transaction(sender_c, details_c, &call) == GA_OK);
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_request_code(call, "gauth") == GA_OK);
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_resolve_code(call, DUMMY_CODE.c_str()) == GA_OK);
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_call(call) == GA_OK);
            GA_json* transaction_c = nullptr;
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_get_status(call, &transaction_c) == GA_OK);
            transaction = (*(reinterpret_cast<nlohmann::json*>(transaction_c)))["result"];

            sender.disable_twofactor("gauth", { { "method", "gauth" }, { "code", DUMMY_CODE } });
        }
        // std::cerr << "sent: " << std::endl << transaction.dump() << std::endl << std::endl;

        // Get the transaction details from the server to compare
        nlohmann::json tx_details = sender.get_transaction_details(transaction["txhash"]);
        GA_SDK_RUNTIME_ASSERT(tx_details["transaction"] == transaction["transaction"]);
        GA_SDK_RUNTIME_ASSERT(tx_details["txhash"] == transaction["txhash"]);
        // std::cerr << "tx_details: " << std::endl << tx_details.dump() << std::endl;

        // nlohmann::json txs = sender.get_transactions(0, 0);
        // std::cerr << "txs: " << std::endl << txs.dump() << std::endl;

        // FIXME: Bump and re-send
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
