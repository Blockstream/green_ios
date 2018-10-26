#ifndef GA_SDK_UTILS_HPP
#define GA_SDK_UTILS_HPP
#pragma once

#include <cstddef>
#include <map>
#include <string>

#include "containers.hpp"
#include "ga_wally.hpp"
#include "include/common.h"

namespace ga {
namespace sdk {
    GASDK_API void get_random_bytes(std::size_t num_bytes, void* output_bytes, std::size_t siz);

    // Return a uint32_t in the range 0 to (upper_bound - 1) without bias
    GASDK_API uint32_t get_uniform_uint32_t(uint32_t upper_bound);

    template <std::size_t N> std::array<unsigned char, N> get_random_bytes()
    {
        std::array<unsigned char, N> buff{ { 0 } };
        get_random_bytes(N, buff.data(), buff.size());
        return buff;
    }

    template <typename InputIt, typename OutputIt, typename BinaryOperation>
    void adjacent_transform(InputIt first, InputIt last, OutputIt d_first, BinaryOperation binary_op)
    {
        auto next = first;
        while (next != last) {
            auto prev = next++;
            *d_first++ = binary_op(*prev, *next++);
        }
    }

    std::vector<unsigned char> bytes_from_hex(const char* hex, size_t siz);
    inline auto bytes_from_hex(const std::string& hex) { return bytes_from_hex(hex.data(), hex.size()); }

    std::vector<unsigned char> bytes_from_hex_rev(const char* hex, size_t siz);
    inline auto bytes_from_hex_rev(const std::string& hex) { return bytes_from_hex_rev(hex.data(), hex.size()); }

    GASDK_API nlohmann::json parse_bitcoin_uri(const std::string& s);

    // Mnemonic handling
    std::string encrypt_mnemonic(const std::string& plaintext_mnemonic, const std::string& password);
    std::string decrypt_mnemonic(const std::string& encrypted_mnemonic, const std::string& password);

    // Encryption
    nlohmann::json encrypt_data(const nlohmann::json& input, const std::vector<unsigned char>& default_password);
    nlohmann::json decrypt_data(const nlohmann::json& input, const std::vector<unsigned char>& default_password);
    std::string aes_cbc_decrypt(
        const std::array<unsigned char, PBKDF2_HMAC_SHA256_LEN>& key, const std::string& ciphertext);
    std::string aes_cbc_encrypt(
        const std::array<unsigned char, PBKDF2_HMAC_SHA256_LEN>& key, const std::string& plaintext);
} // namespace sdk
} // namespace ga

#endif
