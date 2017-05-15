#ifndef GA_SDK_UTILS_HPP
#define GA_SDK_UTILS_HPP
#pragma once

namespace ga {
namespace sdk {

    namespace detail {
        template <size_t N, size_t... I>
        struct make_even_index_sequence : make_even_index_sequence<N - 2, N - 2, I...> {
        };

        template <size_t... I> struct make_even_index_sequence<0, I...> {
            using type = std::index_sequence<I...>;
        };

        template <size_t N> using make_even_index_sequence_t = typename make_even_index_sequence<N>::type;

        template <typename Args, size_t... I> inline auto make_map_from_args(Args&& args, std::index_sequence<I...>)
        {
            return std::map<int, int>{ { static_cast<int>(std::get<I>(std::forward<Args>(args))),
                static_cast<int>(std::get<I + 1>(std::forward<Args>(args))) }... };
        }

        template <size_t N, size_t... I>
        inline constexpr auto constant_string(const char (&s)[N], std::index_sequence<I...>)
        {
            return std::make_tuple(s[I]...);
        }

        template <size_t N> inline constexpr auto constant_string(const char (&s)[N])
        {
            return constant_string(s, std::make_index_sequence<N - 1>());
        }
    }

    template <typename T, size_t... I> inline std::string make_string(T s, std::index_sequence<I...>)
    {
        return std::string{ std::get<I>(s)... };
    }

    template <typename T> inline std::string make_string(T s)
    {
        return make_string(s, std::make_index_sequence<std::tuple_size<T>::value>());
    }

    template <typename... Args> inline auto make_map_from_args(Args&&... args)
    {
        static_assert(sizeof...(Args) % 2 == 0);
        return detail::make_map_from_args(
            std::make_tuple(std::forward<Args>(args)...), detail::make_even_index_sequence_t<sizeof...(Args)>{});
    }

    template <typename Args> inline auto make_map_from_args(Args&& args)
    {
        return detail::make_map_from_args(std::make_tuple(std::forward<Args>(args), std::forward<Args>(args)),
            detail::make_even_index_sequence_t<2>{});
    }
}
}

#endif
