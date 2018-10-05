#include <iostream>
#include <string>
#include <vector>

#include "argparser.h"

#include "http_jsonrpc_interface.hpp"
#include "include/session.h"
#include "include/session.hpp"
#include "include/twofactor.h"
#include "tests/utils.hpp"

using namespace ga;

namespace {
static const std::string DUMMY_CODE = "555555";
static const std::string TWOFACTOR_GAUTH = "gauth";
static const std::string TWOFACTOR_EMAIL = "email";

static const std::string DEFAULT_MNEMONIC_1(
    "infant earth modify pyramid hunt reopen write asthma middle during mechanic "
    "carry health chat plate wear cycle market knock number blur near permit core");

static const std::string DEFAULT_MNEMONIC_2(
    "sustain pumpkin scrub about voyage laptop script engine upset spoil nerve chicken tackle analyst "
    "actress gauge second pink hero rack warm detail sleep dawn");

static void login(sdk::session& session, const std::string& mnemonic, struct options* options)
{
    const bool debug = options->quiet == 0;
    session.connect(options->testnet ? sdk::make_testnet_network() : sdk::make_localtest_network(), debug);
    session.register_user(mnemonic);
    session.login(mnemonic);
}

static nlohmann::json get_tx_list_tx(sdk::session& session, const std::string& txhash)
{
    const nlohmann::json txs = session.get_transactions(0, 0);
    // std::cerr << "txs: " << std::endl << txs.dump() << std::endl;
    const auto& tx_list = txs["list"];
    const auto tx_p = std::find_if(
        std::begin(tx_list), std::end(tx_list), [&txhash](const nlohmann::json& tx) { return tx["txhash"] == txhash; });
    GA_SDK_RUNTIME_ASSERT(tx_p != std::end(tx_list));
    return *tx_p;
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

        // const std::string& TWOFACTOR_METHOD = TWOFACTOR_GAUTH;
        const std::string& TWOFACTOR_METHOD = TWOFACTOR_EMAIL;
        if (!options->testnet) {
            // On localtest, enable 2fa to test sending with 2fa enabled (but
            // only if not already enabled from a previous failed test run)
            if (!sender.get_twofactor_config()[TWOFACTOR_METHOD].value("enabled", false)) {
                if (TWOFACTOR_METHOD == TWOFACTOR_GAUTH) {
                    sender.enable_gauth(DUMMY_CODE, nlohmann::json());
                } else {
                    const std::string email = "@@" + get_random_string();
                    if (!sender.get_twofactor_config()[TWOFACTOR_METHOD].value("confirmed", false)) {
                        sender.set_email(email, nlohmann::json());
                        sender.activate_email(DUMMY_CODE);
                    }
                    sender.init_enable_twofactor(TWOFACTOR_METHOD, email, nlohmann::json());
                    sender.enable_twofactor(TWOFACTOR_METHOD, DUMMY_CODE);
                }
            }
        }

        const uint32_t num_confs = 1;
        nlohmann::json sender_utxos = sender.get_unspent_outputs(0, num_confs);

        if (sender_utxos.size() < 10u) {
            std::cerr << "Generating utxos for sending" << std::endl;

            // Give the sender some confirmed UTXOs to spend
            std::vector<std::pair<std::string, double>> address_amounts;
            for (size_t i = 0; i < 15u; ++i) {
                const std::string addr = sender.get_receive_address(0)["address"];
                address_amounts.emplace_back(std::make_pair(addr, 0.5));
            }
            sdk::http_jsonrpc_client rpc;
            const auto send_request = rpc.make_sendmany_request(address_amounts);
            rpc.sync_post("127.0.0.1", "19001", send_request);

            rpc.sync_post("127.0.0.1", "19001", rpc.make_generate_request(1));

            // FIXME: should really wait for the block notification here
            sender_utxos = sender.get_unspent_outputs(0, num_confs);
        }
        const size_t num_sender_utxos = sender_utxos.size();

        const std::string recv_addr = receiver.get_receive_address(0)["address"];
#if 0
        // Sample regtest addresses for debugging
        const std::string recv_addr{ "mnvL3wwo8sPCkHbkdq3Lzc2Y4NhguNKnyk" }; // P2PKH
        const std::string recv_addr{ "bcrt1q0wamd2z3yxrwa3c96knlfdjntj6hhngweuj4vv" }; // P2WPKH
        const std::string recv_addr{ "bcrt1qkk3vjcjsvy3kd6389lavdkt5f2h5k3d2ekt25l8uhyc7uw64sfvsk5excw" }; // P2WSH
#endif
        // Send using BIP21 URI
        const std::vector<nlohmann::json> addressees{ { { "address", "bitcoin:" + recv_addr + "?amount=0.01" } } };

        // Create a tx to send. In a wallet this would be an iterative processes
        // as the user adjusts amounts etc.
        // Here we allow the create_transaction defaulting to add utxos for us
        nlohmann::json details = sender.create_transaction({ { "addressees", addressees }, { "fee_rate", 1000 } });
        // std::cerr << "initial: " << std::endl << details.dump() << std::endl << std::endl;

        // Make a note of our change address
        GA_SDK_RUNTIME_ASSERT(details.value("have_change", false));
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

        nlohmann::json orig_tx;
        if (options->testnet) {
            // Send the transaction, signing it automatically
            orig_tx = sender.send_transaction(details, nlohmann::json());
        } else {
            // Test sending with 2fa enabled through the call interface
            struct GA_twofactor_call* call = nullptr;
            struct GA_session* sender_c = reinterpret_cast<struct GA_session*>(&sender);
            struct GA_json* details_c = reinterpret_cast<struct GA_json*>(&details);
            GA_SDK_RUNTIME_ASSERT(GA_send_transaction(sender_c, details_c, &call) == GA_OK);
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_request_code(call, TWOFACTOR_METHOD.c_str()) == GA_OK);
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_resolve_code(call, DUMMY_CODE.c_str()) == GA_OK);
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_call(call) == GA_OK);
            GA_json* transaction_c = nullptr;
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_get_status(call, &transaction_c) == GA_OK);
            orig_tx = (*(reinterpret_cast<nlohmann::json*>(transaction_c)))["result"];

            if (TWOFACTOR_METHOD == TWOFACTOR_EMAIL) {
                sender.twofactor_request_code(TWOFACTOR_EMAIL, "disable_2fa", { { "method", TWOFACTOR_METHOD } });
            }
            sender.disable_twofactor(TWOFACTOR_METHOD, { { "method", TWOFACTOR_METHOD }, { "code", DUMMY_CODE } });
        }
        // std::cerr << "sent: " << std::endl << orig_tx.dump() << std::endl << std::endl;

        // Get the transaction details from the server to compare
        nlohmann::json tx_details = sender.get_transaction_details(orig_tx["txhash"]);
        GA_SDK_RUNTIME_ASSERT(tx_details["transaction"] == orig_tx["transaction"]);
        std::string txhash = tx_details["txhash"];
        GA_SDK_RUNTIME_ASSERT(txhash == orig_tx["txhash"]);
        // std::cerr << "tx_details: " << std::endl << tx_details.dump() << std::endl;

        // Make sure the tx is in our tx list and is bumpable
        const auto rbf_tx = get_tx_list_tx(sender, txhash);
        GA_SDK_RUNTIME_ASSERT(rbf_tx.value("can_rbf", false) == true);
        GA_SDK_RUNTIME_ASSERT(rbf_tx.value("can_cpfp", true) == false);

        // RBF it
        details = sender.create_transaction({ { "previous_transaction", rbf_tx }, { "fee_rate", 2000 } });
        // std::cerr << "bumped: " << std::endl << details.dump() << std::endl << std::endl;

        // Sign/Send it
        nlohmann::json sent_rbf_tx = sender.send_transaction(details, nlohmann::json());
        // std::cerr << "sent bumped: " << std::endl << sent_rbf_tx.dump() << std::endl << std::endl;

        // Receiver CPFP's it
        txhash = sent_rbf_tx["txhash"];
        const auto cpfp_tx = get_tx_list_tx(receiver, txhash);
        // std::cerr << "received tx: " << std::endl << cpfp_tx.dump() << std::endl << std::endl;
        GA_SDK_RUNTIME_ASSERT(cpfp_tx.value("can_rbf", true) == false);
        GA_SDK_RUNTIME_ASSERT(cpfp_tx.value("can_cpfp", false) == true);

        details = receiver.create_transaction({ { "previous_transaction", cpfp_tx }, { "fee_rate", 3000 } });
        // std::cerr << "received CPFP: " << std::endl << details.dump() << std::endl << std::endl;

        // FIXME: CPFP requires a backend fix which is not yet merged
#if 0
        // Sign/Send it
        nlohmann::json sent_cpfp_tx = receiver.send_transaction(details, nlohmann::json());
        // std::cerr << "sent cpfp: " << std::endl << sent_cpfp_tx.dump() << std::endl << std::endl;
#endif
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
