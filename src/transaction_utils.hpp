#ifndef GA_SDK_TRANSACTION_UTILS_HPP
#define GA_SDK_TRANSACTION_UTILS_HPP
#pragma once

#include <array>
#include <memory>
#include <utility>
#include <vector>

#include "containers.hpp"
#include "wally_wrapper.h"

namespace ga {
namespace sdk {

    using wally_ext_key_ptr = std::unique_ptr<const ext_key, decltype(&bip32_key_free)>;

    wally_ext_key_ptr derive_key(const wally_ext_key_ptr& key, std::uint32_t child, bool public_);

    wally_ext_key_ptr derive_key(
        const wally_ext_key_ptr& key, std::pair<std::uint32_t, std::uint32_t> path, bool public_);

    wally_ext_key_ptr ga_pub_key(const std::string& chain_code, const std::string& pub_key,
        const std::string& gait_path, uint32_t subaccount, uint32_t pointer, bool main_net);

    std::array<unsigned char, HASH160_LEN + 1> create_p2sh_script(const std::vector<unsigned char>& script_bytes);
    std::array<unsigned char, HASH160_LEN + 1> create_p2wsh_script(const std::vector<unsigned char>& script_bytes);
    std::array<unsigned char, HASH160_LEN + 3> output_script_for_address(const std::string& address);
    std::array<unsigned char, HASH160_LEN + 3> output_script(
        const std::array<unsigned char, HASH160_LEN + 1>& script_hash);

    std::vector<unsigned char> output_script(const wally_ext_key_ptr& key, const std::string& deposit_chain_code,
        const std::string& deposit_pub_key, const std::string& gait_path, uint32_t subaccount, uint32_t pointer,
        bool main_net);

    std::vector<unsigned char> input_script(
        const std::array<std::array<unsigned char, EC_SIGNATURE_DER_MAX_LEN + 1>, 2>& sigs, size_t sigs_size,
        size_t num_sigs, const std::vector<unsigned char>& output_script);
}
}

#endif
