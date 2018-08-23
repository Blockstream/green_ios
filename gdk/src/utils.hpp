#ifndef GA_SDK_UTILS_HPP
#define GA_SDK_UTILS_HPP
#pragma once

#include <cstddef>
#include <map>
#include <string>

#include "containers.hpp"
#include "memory.hpp"

namespace ga {
namespace sdk {
    void get_random_bytes(std::size_t num_bytes, void* output_bytes, std::size_t siz);

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

    secure_array<unsigned char, BIP39_ENTROPY_LEN_256> mnemonic_to_bytes(
        const std::string& mnemonic, const std::string& lang);

    std::string mnemonic_from_bytes(const unsigned char* entropy, size_t siz, const char* lang);
    void mnemonic_validate(const std::string& lang, const std::string& mnemonic);
    std::string generate_mnemonic();

    bitcoin_uri parse_bitcoin_uri(const std::string& s);
} // namespace sdk
} // namespace ga

#endif
