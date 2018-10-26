#ifndef GA_SDK_TRANSACTION_UTILS_HPP
#define GA_SDK_TRANSACTION_UTILS_HPP
#pragma once

#include <array>
#include <memory>
#include <utility>

#include "include/amount.hpp"
#include "signer.hpp"

namespace ga {
namespace sdk {
    class session;

    enum class script_type : int {
        p2sh_fortified_out = 10,
        p2sh_p2wsh_fortified_out = 14,
        p2sh_p2wsh_csv_fortified_out = 15,
        redeem_p2sh_fortified = 150,
        redeem_p2sh_p2wsh_fortified = 159,
        redeem_p2sh_p2wsh_csv_fortified = 162
    };

    inline bool is_segwit_script_type(script_type type)
    {
        return type == script_type::p2sh_p2wsh_fortified_out || type == script_type::p2sh_p2wsh_csv_fortified_out
            || type == script_type::redeem_p2sh_p2wsh_fortified || type == script_type::redeem_p2sh_p2wsh_csv_fortified;
    }

    std::string get_address_from_script(
        const network_parameters& net_params, byte_span_t script, const std::string& addr_type);

    std::vector<unsigned char> output_script_for_address(
        const network_parameters& net_params, const std::string& address);

    std::vector<unsigned char> output_script(ga_pubkeys& pubkeys, ga_user_pubkeys& user_pubkeys,
        ga_user_pubkeys& recovery_pubkeys, uint32_t subaccount, const nlohmann::json& data);

    // Make a multisig scriptSig
    std::vector<unsigned char> input_script(signer& user_signer, const std::vector<unsigned char>& prevout_script,
        const ecdsa_sig_t& user_sig, const ecdsa_sig_t& ga_sig);

    // Make a multisig scriptSig with a user signature and PUSH(0) marker for the GA sig
    std::vector<unsigned char> input_script(
        signer& user_signer, const std::vector<unsigned char>& prevout_script, const ecdsa_sig_t& user_sig);

    // Make a multisig scriptSig with dummy signatures for (fee estimation)
    std::vector<unsigned char> dummy_input_script(
        signer& user_signer, const std::vector<unsigned char>& prevout_script);

    std::vector<unsigned char> witness_script(const std::vector<unsigned char>& script);

    // Compute the fee for a tx
    amount get_tx_fee(const wally_tx_ptr& tx, amount min_fee_rate, amount fee_rate);

    // Add an output to a tx given its address
    amount add_tx_output(
        const network_parameters& net_params, wally_tx_ptr& tx, const std::string& address, uint32_t satoshi = 0);

    // Add an output from a JSON addressee
    amount add_tx_addressee(session& session, const network_parameters& net_params, wally_tx_ptr& tx,
        nlohmann::json& result, const nlohmann::json& addressee);

    // Update the json tx representation with info from tx
    void update_tx_info(const wally_tx_ptr& tx, nlohmann::json& result);

    // Set the locktime on tx to avoid fee sniping
    void set_anti_snipe_locktime(const wally_tx_ptr& tx, uint32_t current_block_height);
} // namespace sdk
} // namespace ga

#endif
