#ifndef GA_SDK_UTILS_HPP
#define GA_SDK_UTILS_HPP
#pragma once

#include <cstddef>
#include <map>
#include <string>

#include "containers.hpp"
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

    // FIXME: secure_vector
    std::vector<unsigned char> mnemonic_to_bytes(const std::string& mnemonic);

    GASDK_API std::string mnemonic_from_bytes(const unsigned char* entropy, size_t siz);
    std::string generate_mnemonic();

    GASDK_API nlohmann::json parse_bitcoin_uri(const std::string& s);
} // namespace sdk
} // namespace ga

#endif
