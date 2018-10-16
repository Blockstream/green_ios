#include <algorithm>
#include <array>
#include <ctime>
#include <gsl/span>
#include <string>
#include <vector>

#include "boost_wrapper.hpp"

#include "include/session.hpp"
#include "transaction_utils.hpp"
#include "utils.hpp"

namespace ga {
namespace sdk {
    namespace {
        // Dummy data for transaction creation with correctly sized data for fee estimation
        static const std::vector<unsigned char> DUMMY_WITNESS_SCRIPT(3 + SHA256_LEN);

        static const std::string UTXO_SEL_DEFAULT("default"); // Use the default utxo selection strategy
        static const std::string UTXO_SEL_MANUAL("manual"); // Use manual utxo selection

        static const uint32_t NO_CHANGE_INDEX = -1;

        // Add a UTXO to a transaction. Returns the amount added
        static amount add_utxo(session& session, const wally_tx_ptr& tx, const nlohmann::json& u)
        {
            const std::string txhash = u["txhash"];
            const uint32_t index = u["pt_idx"];
            const uint32_t sequence = session.is_rbf_enabled() ? 0xFFFFFFFD : 0xFFFFFFFE;
            const uint32_t subaccount = json_get_value(u, "subaccount", 0u);
            const auto type = script_type(u["script_type"]);

            // TODO: Create correctly sized dummys instead of actual script (faster)
            const auto prevout_script = session.output_script(subaccount, u);
            wally_tx_witness_stack_ptr wit;

            if (is_segwit_script_type(type)) {
                // TODO: If the UTXO is CSV and expired, spend it using the users key only (smaller)
                wit = tx_witness_stack_init(4);
                tx_witness_stack_add_dummy(wit, WALLY_TX_DUMMY_NULL);
                tx_witness_stack_add_dummy(wit, WALLY_TX_DUMMY_SIG_LOW_R);
                tx_witness_stack_add_dummy(wit, WALLY_TX_DUMMY_SIG_LOW_R);
                tx_witness_stack_add(wit, prevout_script);
            }

            tx_add_raw_input(tx, bytes_from_hex_rev(txhash), index, sequence,
                wit ? DUMMY_WITNESS_SCRIPT : dummy_input_script(prevout_script), wit, 0);

            return amount(u["satoshi"]);
        }

        // Check if a tx to bump is present, and if so add the details required to bump it
        static std::pair<bool, bool> check_bump_tx(session& session, nlohmann::json& result)
        {
            if (result.find("previous_transaction") == result.end()) {
                return std::make_pair(false, false);
            }

            // RBF or CPFP. The previous transaction must be in the format
            // returned from the get_transactions call
            const auto& prev_tx = result["previous_transaction"];
            bool is_rbf = false, is_cpfp = false;
            if (prev_tx.value("can_rbf", false)) {
                is_rbf = true;
            } else if (prev_tx.value("can_cpfp", false)) {
                is_cpfp = true;
            } else {
                // Transaction is confirmed or marked non-RBF
                GA_SDK_RUNTIME_ASSERT_MSG(false, "Transaction can not be fee-bumped");
            }

            auto tx = tx_from_hex(prev_tx["transaction"]);
            const auto min_fee_rate = session.get_min_fee_rate();

            // Store the old fee to determine the fee increment
            const amount old_fee = amount(prev_tx["fee"]);
            result["old_fee"] = old_fee.value();

            if (is_rbf) {
                if (result.find("network_fee") == result.end()) {
                    // Compute the bandwidth fee that must be paid for the old tx
                    // Since the tx being bumped chan't change, we only need to
                    // compute this once no matter what the user changes
                    const auto network_fee = get_tx_fee(tx, min_fee_rate, min_fee_rate);
                    result["network_fee"] = network_fee.value();
                }
            } else {
                // For CPFP the network fee is the difference between the
                // fee the previous transaction currently pays, and the
                // fee it would pay at the desired new fee rate (adding
                // the network fee to the new transactions fee increases
                // the overall fee rate of the pair to the desired rate,
                // so that miners are incentivized to mine both together).
                const amount new_fee_rate = amount(result["fee_rate"]);
                const auto new_fee = get_tx_fee(tx, min_fee_rate, new_fee_rate);
                const amount network_fee = new_fee <= old_fee ? amount() : new_fee;
                result["network_fee"] = network_fee.value();
            }

            if (is_rbf) {
                // Compute addressees and any change details from the old tx
                std::vector<nlohmann::json> addressees;
                addressees.reserve(prev_tx["outputs"].size());
                uint32_t i = 0, change_index = NO_CHANGE_INDEX;
                for (const auto& output : prev_tx["outputs"]) {
                    if (output.value("is_relevant", false) && change_index == NO_CHANGE_INDEX) {
                        // Change output. If there is already one we treat it as a regular output
                        change_index = i;
                        result["change_address"] = output["address"];
                        result["change_subaccount"] = output["subaccount"];
                    } else {
                        addressees.emplace_back(
                            nlohmann::json({ { "address", output["address"] }, { "satoshi", output["satoshi"] } }));
                    }
                    ++i;
                }
                result["addressees"] = addressees;

                result["have_change"] = change_index != NO_CHANGE_INDEX;
                if (change_index == NO_CHANGE_INDEX) {
                    // FIXME: When the server supports multiple subaccount sends, this
                    // will need to change to something smarter
                    const uint32_t subaccount = prev_tx["subaccount"];
                    result["subaccount"] = subaccount;
                    result["change_subaccount"] = subaccount;
                }

                if (result.find("old_used_utxos") == result.end()) {
                    // Create 'fake' utxos for the existing inputs
                    std::map<uint32_t, nlohmann::json> used_utxos_map;
                    for (const auto& input : prev_tx["inputs"]) {
                        GA_SDK_RUNTIME_ASSERT(input.value("is_relevant", false));
                        nlohmann::json utxo(input);
                        // Note pt_idx on endpoints is the index within the tx, not the previous tx!
                        const uint32_t i = input["pt_idx"];
                        GA_SDK_RUNTIME_ASSERT(i < tx->num_inputs);
                        std::reverse(&tx->inputs[i].txhash[0], &tx->inputs[i].txhash[0] + WALLY_TXHASH_LEN);
                        utxo["txhash"] = hex_from_bytes(gsl::make_span(tx->inputs[i].txhash));
                        utxo["pt_idx"] = tx->inputs[i].index;
                        used_utxos_map.emplace(i, utxo);
                    }
                    GA_SDK_RUNTIME_ASSERT(used_utxos_map.size() == tx->num_inputs);
                    std::vector<nlohmann::json> old_used_utxos;
                    old_used_utxos.reserve(used_utxos_map.size());
                    for (const auto& input : used_utxos_map) {
                        old_used_utxos.emplace_back(input.second);
                    }
                    result["old_used_utxos"] = old_used_utxos;
                }
                if (json_get_value(result, "memo").empty()) {
                    result["memo"] = prev_tx["memo"];
                }
                // FIXME: Carry over payment request details?
            } else {
                // For CPFP construct a tx spending an input from prev_tx
                // to a wallet change address. Since this is exactly what
                // re-depositing requires, just create the input and mark
                // the tx as a redeposit to let the regular creation logic
                // handle it.
                result["is_redeposit"] = true;
                if (result.find("utxos") == result.end()) {
                    // Add a single output from the old tx as our new tx input
                    std::vector<nlohmann::json> utxos;
                    for (const auto& output : prev_tx["outputs"]) {
                        if (output.value("is_relevant", false)) {
                            // First output paying to us, use it as the new tx input
                            nlohmann::json utxo(output);
                            utxo["txhash"] = prev_tx["txhash"];
                            utxos.emplace_back(utxo);
                            break;
                        }
                    }
                    GA_SDK_RUNTIME_ASSERT(utxos.size() == 1u);
                    result["utxos"] = utxos;
                }
            }
            return std::make_pair(is_rbf, is_cpfp);
        }
    } // namespace

    nlohmann::json create_ga_transaction(
        session& session, const network_parameters& net_params, const nlohmann::json& details)
    {
        // Copy all inputs into our result (they will be overridden below as needed)
        nlohmann::json result(details); // FIXME: support in place for calling from send

        result["error"] = std::string(); // Clear any previous error
        result["user_signed"] = false;
        result["server_signed"] = false;

        // Check for RBF/CPFP
        bool is_rbf, is_cpfp;
        std::tie(is_rbf, is_cpfp) = check_bump_tx(session, result);

        const uint32_t current_subaccount = result.value("subaccount", session.get_current_subaccount());

        const bool is_redeposit = result.value("is_redeposit", false);

        if (is_redeposit) {
            if (result.find("addressees") == result.end()) {
                // For re-deposit/CPFP, create the addressee if not present already
                const auto address = session.get_receive_address(current_subaccount)["address"];
                std::vector<nlohmann::json> addressees;
                addressees.emplace_back(nlohmann::json({ { "address", address }, { "satoshi", 0 } }));
                result["addressees"] = addressees;
            }
            // When re-depositing, send everything and don't create change
            result["send_all"] = true;
        }
        result["is_redeposit"] = is_redeposit;

        // Let the caller know if addressees should not be modified
        result["addressees_read_only"] = is_redeposit || is_rbf || is_cpfp;

        if (result.find("utxos") == result.end()) {
            // Fetch the users utxos from the current subaccount.
            // Always spend utxos with 1 confirmation, unless we are in testnet.
            // Even in testnet, if RBFing, require 1 confirmation.
            const bool main_net = net_params.main_net();
            const uint32_t num_confs = main_net || is_rbf || is_cpfp ? 1 : 0;
            result["utxos"] = session.get_unspent_outputs(current_subaccount, num_confs);
        }

        const bool send_all = json_add_if_missing(result, "send_all", false);
        const std::string strategy = json_add_if_missing(result, "utxo_strategy", UTXO_SEL_DEFAULT);
        const bool manual_selection = strategy == UTXO_SEL_MANUAL;
        GA_SDK_RUNTIME_ASSERT(strategy == UTXO_SEL_DEFAULT || manual_selection);
        if (!manual_selection) {
            // We will recompute the used utxos
            result.erase("used_utxos");
        }

        // We must have addressees to send to, and if sending everything, only one
        const auto& addressees = result.at("addressees");
        if (addressees.empty()) {
            result["error"] = "No outputs";
            return result;
        }

        // Send all should not be visible/set when RBFing
        GA_SDK_RUNTIME_ASSERT(!is_rbf || !send_all);

        if (send_all && addressees.size() > 1) {
            result["error"] = "Send all requires a single output";
            return result;
        }

        const auto& utxos = result["utxos"];
        const uint32_t current_block_height = session.get_block_height();
        const uint32_t num_extra_utxos = is_rbf ? result["old_used_utxos"].size() : 0;
        wally_tx_ptr tx = tx_init(current_block_height, utxos.size() + num_extra_utxos, addressees.size() + 1);
        if (!is_rbf) {
            set_anti_snipe_locktime(tx, current_block_height);
        }

        // Add all outputs and compute the total amount of satoshi to be sent
        amount required_total{ 0 };

        for (const auto& addressee : addressees) {
            required_total += add_tx_addressee(session, net_params, tx, addressee);
        }

        std::vector<uint32_t> used_utxos;
        used_utxos.reserve(utxos.size());
        uint32_t utxo_index = 0;

        amount available_total, total, fee, v;

        if (is_rbf) {
            // Add all the old utxos. Note we don't add them to used_utxos
            // since the user can't choose to remove them
            for (const auto& utxo : result["old_used_utxos"]) {
                v = add_utxo(session, tx, utxo);
                available_total += v;
                total += v;
                ++utxo_index;
            }
        }

        if (manual_selection) {
            // Add all selected utxos
            for (const auto& ui : result["used_utxos"]) {
                utxo_index = ui;
                v = add_utxo(session, tx, utxos.at(utxo_index));
                available_total += v;
                total += v;
                used_utxos.emplace_back(utxo_index);
            }
        } else {
            // Collect utxos in order until we have covered the amount to send
            // FIXME: Better coin selection algorithms (esp. minimum size)
            for (const auto& utxo : utxos) {
                if (send_all || total < required_total) {
                    v = add_utxo(session, tx, utxo);
                    total += v;
                    used_utxos.emplace_back(utxo_index);
                    ++utxo_index;
                } else {
                    v = static_cast<amount::value_type>(utxo["satoshi"]);
                }
                available_total += v;
            }
        }

        // Return the available total for client insufficient fund handling
        result["available_total"] = available_total.value();

        bool have_change = false;
        uint32_t change_index = NO_CHANGE_INDEX;
        if (is_rbf) {
            have_change = result.value("have_change", false);
            if (have_change) {
                add_tx_output(net_params, tx, result["change_address"]);
                change_index = tx->num_outputs - 1;
            }
        }

        const amount dust_threshold = session.get_dust_threshold();
        const amount user_fee_rate = amount(result.at("fee_rate"));
        const amount min_fee_rate = session.get_min_fee_rate();
        const amount old_fee = amount(result.value("old_fee", 0));
        const amount network_fee = amount(result.value("network_fee", 0));

        for (;;) {
            const amount min_change = have_change ? amount() : dust_threshold;

            fee = get_tx_fee(tx, min_fee_rate, user_fee_rate);
            // For RBF, the new fee must be larger than the old fee *before*
            // the bandwidth fee is added
            fee = fee < old_fee ? old_fee + 1 : fee;
            const amount fee_increment = fee - old_fee + network_fee;
            fee += network_fee;

            if (send_all) {
                required_total = total - fee - min_change;
                tx->outputs[0].satoshi = required_total.value();
            }

            const amount am = required_total + fee + min_change;
            if (total < am) {
                if (manual_selection || used_utxos.size() == utxos.size()) {
                    // Used all inputs and do not have enough funds
                    result["error"] = "Insufficient funds";
                    return result;
                }

                // FIXME: Use our strategy here when non-default implemented
                total += add_utxo(session, tx, utxos[tx->num_inputs]);
                used_utxos.emplace_back(utxo_index);
                ++utxo_index;
                continue;
            }

            if (total == am || have_change) {
                result["fee"] = fee.value();
                result["fee_increment"] = fee_increment.value();
                result["network_fee"] = network_fee.value();
                break;
            }

            // Add a change output, re-using the previously generated change
            // address if we can
            std::string change_address = json_get_value(result, "change_address");
            if (change_address.empty()) {
                // Find out where to send any change
                uint32_t change_subaccount = result.value("change_subaccount", current_subaccount);
                // TODO: store change address meta data and pass it to the
                // server to validate when sending (requires backend support)
                change_address = session.get_receive_address(change_subaccount)["address"];
                result["change_subaccount"] = change_subaccount;
                result["change_address"] = change_address;
            }
            add_tx_output(net_params, tx, change_address);
            have_change = true;
            change_index = tx->num_outputs - 1;
        }

        result["used_utxos"] = used_utxos;
        result["have_change"] = have_change;
        result["satoshi"] = required_total.value();

        amount::value_type change_amount = 0;
        if (have_change) {
            // Set the change amount
            auto& change_output = tx->outputs[change_index];
            change_output.satoshi = (total - required_total - fee).value();
            change_amount = change_output.satoshi;
            const uint32_t new_change_index = get_uniform_uint32_t(tx->num_outputs);
            if (change_index != new_change_index) {
                // Randomize change output
                std::swap(tx->outputs[new_change_index], change_output);
                change_index = new_change_index;
            }
        }
        result["change_amount"] = change_amount;
        result["change_index"] = change_index;

        if (user_fee_rate < min_fee_rate) {
            result["error"] = "Fee rate is below minimum accepted fee rate";
        }
        update_tx_info(tx, result);
        return result;
    }

    nlohmann::json sign_ga_transaction(session& session, const nlohmann::json& details)
    {
        GA_SDK_RUNTIME_ASSERT(json_get_value(details, "error").empty());

        nlohmann::json result(details); // FIXME: support in place for calling from send

        const auto& utxos = result.at("utxos");
        const auto& used_utxos = result.at("used_utxos");

        // FIXME: HW wallet support
        // FIXME: Swept inputs need signing with the sweeping private key
        // which should be passed in the tx details
        auto tx = tx_from_hex(details["transaction"]);
        size_t i = 0;
        if (result.find("old_used_utxos") != result.end()) {
            for (const auto& utxo : result["old_used_utxos"]) {
                session.sign_input(tx, i, utxo);
                ++i;
            }
        }
        for (const auto& ui : used_utxos) {
            const uint32_t utxo_index = ui;
            session.sign_input(tx, i, utxos.at(utxo_index));
            ++i;
        }
        result["user_signed"] = true;
        update_tx_info(tx, result);
        return result;
    }

    nlohmann::json send_ga_transaction(
        session& session, const nlohmann::json& details, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(json_get_value(details, "error").empty());

        if (details.find("transaction") == details.end()) {
            return session.send(session.sign_transaction(session.create_transaction(details)), twofactor_data);
        } else if (!details.value("user_signed", false)) {
            return session.send(session.sign_transaction(details), twofactor_data);
        } else {
            return session.send(details, twofactor_data);
        }
    }
} // namespace sdk
} // namespace ga
