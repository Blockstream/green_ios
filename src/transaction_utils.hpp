#ifndef GA_SDK_TRANSACTION_UTILS_HPP
#define GA_SDK_TRANSACTION_UTILS_HPP
#pragma once

#include <array>
#include <memory>
#include <utility>

#include "containers.hpp"
#include "memory.hpp"

namespace std {
template <> struct default_delete<struct ext_key> {
    void operator()(struct ext_key* ptr) const { ::ga::sdk::bip32_key_free(ptr); }
};

template <> struct default_delete<struct wally_tx_input> {
    void operator()(struct wally_tx_input* ptr) const { ::ga::sdk::tx_input_free(ptr); }
};

template <> struct default_delete<struct wally_tx_witness_stack> {
    void operator()(struct wally_tx_witness_stack* ptr) const { ::ga::sdk::tx_witness_stack_free(ptr); }
};

template <> struct default_delete<struct wally_tx_output> {
    void operator()(struct wally_tx_output* ptr) const { ::ga::sdk::tx_output_free(ptr); }
};

template <> struct default_delete<struct wally_tx> {
    void operator()(struct wally_tx* ptr) const { ::ga::sdk::tx_free(ptr); }
};
}

namespace ga {
namespace sdk {
    enum class script_type : int {
        p2sh_fortified_out = 10,
        p2sh_p2wsh_fortified_out = 14,
        redeem_p2sh_fortified = 150,
        redeem_p2sh_p2wsh_fortified = 159
    };

    using wally_ext_key_ptr = std::unique_ptr<struct ext_key>;
    using wally_tx_input_ptr = std::unique_ptr<struct wally_tx_input>;
    using wally_tx_witness_stack_ptr = std::unique_ptr<struct wally_tx_witness_stack>;
    using wally_tx_output_ptr = std::unique_ptr<struct wally_tx_output>;
    using wally_tx_ptr = std::unique_ptr<struct wally_tx>;

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

    template <typename T>
    inline void derive_private_key(
        const wally_ext_key_ptr& key, const T& v, secure_array<unsigned char, EC_PRIVATE_KEY_LEN>& dest)
    {
        wally_ext_key_ptr derived = derive_key(key, v, false);
        memcpy(dest.data(), derived->priv_key + 1, EC_PRIVATE_KEY_LEN);
    }

    wally_ext_key_ptr ga_pub_key(const std::string& chain_code, const std::string& pub_key,
        const std::string& gait_path, uint32_t subaccount, uint32_t pointer, bool main_net);

    std::array<unsigned char, HASH160_LEN + 1> p2sh_address_from_bytes(
        const secure_vector<unsigned char>& script_bytes);
    std::array<unsigned char, HASH160_LEN + 1> p2wsh_address_from_bytes(
        const secure_vector<unsigned char>& script_bytes);
    std::array<unsigned char, HASH160_LEN + 3> output_script_for_address(const std::string& address);
    std::array<unsigned char, HASH160_LEN + 3> output_script(
        const std::array<unsigned char, HASH160_LEN + 1>& script_hash);

    secure_vector<unsigned char> output_script(const wally_ext_key_ptr& key, const std::string& deposit_chain_code,
        const std::string& deposit_pub_key, const std::string& gait_path, uint32_t subaccount, uint32_t pointer,
        bool main_net);

    secure_vector<unsigned char> input_script(
        const std::array<std::array<unsigned char, EC_SIGNATURE_DER_MAX_LEN + 1>, 2>& sigs,
        const std::array<size_t, 2>& sigs_size, size_t num_sigs, const secure_vector<unsigned char>& output_script);

    std::array<unsigned char, 3 + SHA256_LEN> witness_script(const secure_vector<unsigned char>& script_bytes);

    std::vector<unsigned char> tx_to_bytes(const wally_tx_ptr& tx);
}
}

#endif
