#ifndef GA_SDK_TRANSACTION_UTILS_HPP
#define GA_SDK_TRANSACTION_UTILS_HPP
#pragma once

#include <array>
#include <memory>
#include <utility>

namespace ga {
namespace sdk {
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

    template <typename T>
    inline wally_ext_key_ptr derive_key(
        const wally_ext_key_ptr& key, const T& path, bool public_, bool skip_hash = true)
    {
        uint32_t flags = (public_ ? BIP32_FLAG_KEY_PUBLIC : BIP32_FLAG_KEY_PRIVATE);
        if (skip_hash) {
            flags |= BIP32_FLAG_SKIP_HASH;
        }
        ext_key* p;
        bip32_key_from_parent_path_alloc(key, path, flags, &p);
        return wally_ext_key_ptr{ p };
    }

    // FIXME: secure_array
    template <typename T>
    inline void derive_private_key(
        const wally_ext_key_ptr& key, const T& v, std::array<unsigned char, EC_PRIVATE_KEY_LEN>& dest)
    {
        wally_ext_key_ptr derived = derive_key(key, v, false);
        memcpy(dest.data(), static_cast<unsigned char*>(derived->priv_key) + 1, EC_PRIVATE_KEY_LEN);
    }

    std::array<unsigned char, HASH160_LEN + 1> p2sh_address_from_bytes(
        const network_parameters& net_params, const std::vector<unsigned char>& script);
    std::array<unsigned char, HASH160_LEN + 1> p2sh_p2wsh_address_from_bytes(
        const network_parameters& net_params, const std::vector<unsigned char>& script);
    std::vector<unsigned char> output_script_for_address(
        const network_parameters& net_params, const std::string& address);
    std::array<unsigned char, WALLY_SCRIPTPUBKEY_P2SH_LEN> output_script(
        const std::array<unsigned char, HASH160_LEN + 1>& script_hash);

    std::vector<unsigned char> output_script(const network_parameters& net_params, const wally_ext_key_ptr& key,
        const wally_ext_key_ptr& backup_key, const std::string& gait_path, script_type type, uint32_t subtype,
        uint32_t subaccount, uint32_t pointer);

    // Make a multisig scriptSig
    std::vector<unsigned char> input_script(const std::vector<unsigned char>& prevout_script,
        const std::array<unsigned char, EC_SIGNATURE_LEN>& user_sig,
        const std::array<unsigned char, EC_SIGNATURE_LEN>& ga_sig);

    // Make a multisig scriptSig with a user signature and PUSH(0) marker for the GA sig
    std::vector<unsigned char> input_script(
        const std::vector<unsigned char>& prevout_script, const std::array<unsigned char, EC_SIGNATURE_LEN>& user_sig);

    // Make a multisig scriptSig with dummy signatures for (fee estimation)
    std::vector<unsigned char> dummy_input_script(const std::vector<unsigned char>& prevout_script);

    std::array<unsigned char, 3 + SHA256_LEN> witness_script(const std::vector<unsigned char>& script);

    // Serialize a tx to bytes
    std::vector<unsigned char> tx_to_bytes(const wally_tx_ptr& tx);

    // Compute the fee for a tx
    amount get_tx_fee(const wally_tx_ptr& tx, amount min_fee_rate, amount fee_rate);

    // Add an output to a tx given its address
    void add_tx_output(
        const network_parameters& net_params, wally_tx_ptr& tx, const std::string& address, uint32_t satoshi = 0);

    // Update the json tx representation with info from tx
    void update_tx_info(const wally_tx_ptr& tx, nlohmann::json& result);

    // Set the locktime on tx to avoid fee sniping
    void set_anti_snipe_locktime(const wally_tx_ptr& tx, uint32_t current_block_height);
} // namespace sdk
} // namespace ga

#endif
