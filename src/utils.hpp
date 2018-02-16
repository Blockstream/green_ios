#ifndef GA_SDK_UTILS_HPP
#define GA_SDK_UTILS_HPP
#pragma once

#include <cstddef>
#include <map>
#include <string>
#include <vector>

#include "wally_wrapper.h"

namespace ga {
namespace sdk {

    namespace detail {
        template <std::size_t N, std::size_t... I>
        struct make_even_index_sequence : make_even_index_sequence<N - 2, N - 2, I...> {
        };

        template <std::size_t... I> struct make_even_index_sequence<0, I...> {
            using type = std::index_sequence<I...>;
        };

        template <std::size_t N> using make_even_index_sequence_t = typename make_even_index_sequence<N>::type;

        template <typename Args, std::size_t... I>
        inline auto make_map_from_args(Args&& args, std::index_sequence<I...>)
        {
            return std::map<int, int>{ { static_cast<int>(std::get<I>(std::forward<Args>(args))),
                static_cast<int>(std::get<I + 1>(std::forward<Args>(args))) }... };
        }

        template <std::size_t N, std::size_t... I>
        inline constexpr auto constant_string(const char (&s)[N], std::index_sequence<I...>)
        {
            return std::make_tuple(s[I]...);
        }

        template <std::size_t N> inline constexpr auto constant_string(const char (&s)[N])
        {
            return constant_string(s, std::make_index_sequence<N - 1>());
        }
    }

    template <typename T, std::size_t... I> inline std::string make_string(T s, std::index_sequence<I...>)
    {
        return std::string{ std::get<I>(s)... };
    }

    template <typename T> inline std::string make_string(T s)
    {
        return make_string(s, std::make_index_sequence<std::tuple_size<T>::value>());
    }

    template <typename... Args> inline auto make_map_from_args(Args&&... args)
    {
        static_assert(sizeof...(Args) % 2 == 0, "must be even");
        return detail::make_map_from_args(
            std::make_tuple(std::forward<Args>(args)...), detail::make_even_index_sequence_t<sizeof...(Args)>{});
    }

    template <typename Args> inline auto make_map_from_args(Args&& args)
    {
        return detail::make_map_from_args(std::make_tuple(std::forward<Args>(args), std::forward<Args>(args)),
            detail::make_even_index_sequence_t<2>{});
    }

    void get_random_bytes(std::size_t num_bytes, void* bytes, std::size_t siz);

    template <std::size_t N> std::array<unsigned char, N> get_random_bytes()
    {
        std::array<unsigned char, N> bytes{ { 0 } };
        get_random_bytes(N, bytes.data(), bytes.size());
        return bytes;
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

    using wally_string_ptr = std::unique_ptr<char, decltype(&wally_free_string)>;

    wally_string_ptr hex_from_bytes(const unsigned char* bytes, size_t siz);
    inline wally_string_ptr hex_from_bytes(const std::vector<unsigned char>& bytes)
    {
        return hex_from_bytes(bytes.data(), bytes.size());
    }

    std::vector<unsigned char> bytes_from_hex(const char* hex, size_t siz);
    inline auto bytes_from_hex(const std::string& hex) { return bytes_from_hex(hex.data(), hex.size()); }

    std::array<unsigned char, BIP39_ENTROPY_LEN_256> mnemonic_to_bytes(
        const std::string& mnemonic, const std::string& lang);

    wally_string_ptr mnemonic_from_bytes(const unsigned char* bytes, size_t siz, const char* lang);
}
}

#endif
