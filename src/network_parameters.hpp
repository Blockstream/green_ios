#ifndef GA_SDK_NETWORK_PARAMETERS_HPP
#define GA_SDK_NETWORK_PARAMETERS_HPP
#pragma once

#include <map>
#include <string>
#include <tuple>
#include <utility>

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

#define DEFINE_NETWORK_STRING_PARAM(name, s) const std::string name = s

        struct regtest_parameters final {
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_url, "ws://10.0.2.2:8080/v2/ws");
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_cert_pins, "");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_address, "http://192.168.56.1:8080/address/");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_tx, "http://192.168.56.1:8080/tx/");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_chain_code, "b60befcc619bb1c212732770fe181f2f1aa824ab89f8aab49f2e13e3a56f0f04");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_pub_key, "036307e560072ed6ce0aa5465534fb5c258a2ccfbc257f369e8e7a181b16d897b3");
            DEFINE_NETWORK_STRING_PARAM(gait_onion, "");
            DEFINE_NETWORK_STRING_PARAM(default_peer, "192.168.56.1:19000");
            static constexpr bool main_net = false;
        };

        struct localtest_parameters final {
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_url, "ws://localhost:8080/v2/ws");
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_cert_pins, "");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_address, "");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_tx, "");
            DEFINE_NETWORK_STRING_PARAM(deposit_chain_code, "");
            DEFINE_NETWORK_STRING_PARAM(deposit_pub_key, "");
            DEFINE_NETWORK_STRING_PARAM(gait_onion, "");
            DEFINE_NETWORK_STRING_PARAM(default_peer, "");
            static constexpr bool main_net = false;
        };
    }

#undef DEFINE_NETWORK_STRING_PARAM

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
        return detail::make_map_from_args(
            std::make_tuple(std::forward<Args>(args)...), detail::make_even_index_sequence_t<sizeof...(Args)>{});
    }

    template <typename Args> inline auto make_map_from_args(Args&& args)
    {
        return detail::make_map_from_args(std::make_tuple(std::forward<Args>(args), std::forward<Args>(args)),
            detail::make_even_index_sequence_t<2>{});
    }

    class network_parameters final {
    public:
        template <typename params>
        explicit network_parameters(params p)
            : _gait_wamp_url(p.gait_wamp_url)
            , _gait_wamp_cert_pins(p.gait_wamp_cert_pins)
            , _block_explorer_address(p.block_explorer_address)
            , _block_explorer_tx(p.block_explorer_tx)
            , _deposit_chain_code(p.deposit_chain_code)
            , _deposit_pub_key(p.deposit_pub_key)
            , _gait_onion(p.gait_onion)
            , _default_peer(p.default_peer)
            , _main_net(p.main_net)
        {
        }

        network_parameters(const network_parameters&) = delete;
        network_parameters& operator=(const network_parameters&) = delete;

        network_parameters(network_parameters&&) = default;
        network_parameters& operator=(network_parameters&&) = default;

        const std::string& gait_wamp_url() const { return _gait_wamp_url; }
        const std::string& gait_wamp_cert_pins() const { return _gait_wamp_cert_pins; }
        const std::string& block_explorer_address() const { return _block_explorer_address; }
        const std::string& block_explorer_tx() const { return _block_explorer_tx; }
        const std::string& deposit_chain_code() const { return _deposit_chain_code; }
        const std::string& deposit_pub_key() const { return _deposit_pub_key; }
        const std::string& gait_onion() const { return _gait_onion; }
        bool main_net() const { return _main_net; }

    private:
        std::string _gait_wamp_url;
        std::string _gait_wamp_cert_pins;
        std::string _block_explorer_address;
        std::string _block_explorer_tx;
        std::string _deposit_chain_code;
        std::string _deposit_pub_key;
        std::string _gait_onion;
        std::string _default_peer;
        bool _main_net;
    };

    inline network_parameters make_regtest_network()
    {
        return network_parameters(ga::sdk::detail::regtest_parameters());
    }

    inline network_parameters make_localtest_network()
    {
        return network_parameters(ga::sdk::detail::localtest_parameters());
    }
}
}

#endif
