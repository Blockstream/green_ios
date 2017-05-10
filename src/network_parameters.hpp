#ifndef GA_SDK_NETWORK_PARAMETERS_HPP
#define GA_SDK_NETWORK_PARAMETERS_HPP
#pragma once

#include <string>
#include <tuple>
#include <utility>

namespace ga {
namespace sdk {

    namespace detail {
        template <size_t N, size_t... I>
        inline constexpr auto constant_string(const char (&s)[N], std::index_sequence<I...>)
        {
            return std::make_tuple(s[I]...);
        }

        template <size_t N> inline constexpr auto constant_string(const char (&s)[N])
        {
            return constant_string(s, std::make_index_sequence<N - 1>());
        }

#ifdef __clang__
#define DEFINE_NETWORK_STRING_PARAM(name, s) const std::string name = s
#else
#define DEFINE_NETWORK_STRING_PARAM(name, s) static constexpr auto name = constant_string(s)
#endif

        struct regtest_parameters final {
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_url, "ws://localhost:8080/v2/ws");
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_cert_pins, "");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_address, "http://192.168.56.1:8080/address/");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_tx, "");
            DEFINE_NETWORK_STRING_PARAM(deposit_chain_code, "");
            DEFINE_NETWORK_STRING_PARAM(deposit_pub_key, "");
            DEFINE_NETWORK_STRING_PARAM(gait_onion, "");
            DEFINE_NETWORK_STRING_PARAM(default_peer, "");
            static constexpr bool main_net = false;
        };
    }

    template <typename T, size_t... I> inline std::string make_string(T s, std::index_sequence<I...>)
    {
        return std::string{ std::get<I>(s)... };
    }

    template <typename T> inline std::string make_string(T s)
    {
        return make_string(s, std::make_index_sequence<std::tuple_size<T>::value>());
    }

    inline std::string make_string(const std::string& s) { return s; }

    class network_parameters final {
    public:
        template <typename params>
        network_parameters(params p)
            : _gait_wamp_url(make_string(p.gait_wamp_url))
            , _gait_wamp_cert_pins(make_string(p.gait_wamp_cert_pins))
            , _block_explorer_address(make_string(p.block_explorer_address))
            , _block_explorer_tx(make_string(p.block_explorer_tx))
            , _deposit_chain_code(make_string(p.deposit_chain_code))
            , _deposit_pub_key(make_string(p.deposit_pub_key))
            , _gait_onion(make_string(p.gait_onion))
            , _default_peer(make_string(p.default_peer))
            , _main_net(params::main_net)
        {
        }

        network_parameters(const network_parameters&) = delete;
        network_parameters& operator=(const network_parameters&) = delete;

        network_parameters(network_parameters&&) = default;
        network_parameters& operator=(network_parameters&&) = default;

        const std::string& gait_wamp_url() const { return _gait_wamp_url; }

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
}
}

#endif
