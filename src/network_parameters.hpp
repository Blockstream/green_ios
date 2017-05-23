#ifndef GA_SDK_NETWORK_PARAMETERS_HPP
#define GA_SDK_NETWORK_PARAMETERS_HPP
#pragma once

#include <map>
#include <string>
#include <tuple>
#include <utility>
#include <vector>

namespace ga {
namespace sdk {

    namespace detail {

#define DEFINE_NETWORK_STRING_PARAM(name, s) const std::string name = s
#define DEFINE_NETWORK_VECTOR_STRING_PARAM(name, s, t)                                                                 \
    const std::vector<std::string> name { s, t }

        struct testnet_parameters final {
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_url, "wss://testwss.greenaddress.it/v2/ws");
            DEFINE_NETWORK_VECTOR_STRING_PARAM(gait_wamp_cert_pins,
                "25:84:7D:66:8E:B4:F0:4F:DD:40:B1:2B:6B:07:40:C5:67:DA:7D:02:43:08:EB:6C:2C:96:FE:41:D9:DE:21:8D",
                "A7:4B:0C:32:B6:5B:95:FE:2C:4F:8F:09:89:47:A6:8B:69:50:33:BE:D0:B5:1D:D8:B9:84:EC:AE:89:57:1B:B6");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_address, "https://sandbox.smartbit.com.au/address/");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_tx, "https://sandbox.smartbit.com.au/tx/");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_chain_code, "b60befcc619bb1c212732770fe181f2f1aa824ab89f8aab49f2e13e3a56f0f04");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_pub_key, "036307e560072ed6ce0aa5465534fb5c258a2ccfbc257f369e8e7a181b16d897b3");
            DEFINE_NETWORK_STRING_PARAM(gait_onion, "gu5ke7a2aguwfqhz.onion");
            DEFINE_NETWORK_STRING_PARAM(default_peer, "");
            static constexpr unsigned char btc_version = 111;
            static constexpr bool main_net = false;
        };

        struct regtest_parameters final {
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_url, "ws://10.0.2.2:8080/v2/ws");
            DEFINE_NETWORK_VECTOR_STRING_PARAM(gait_wamp_cert_pins, "", "");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_address, "http://192.168.56.1:8080/address/");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_tx, "http://192.168.56.1:8080/tx/");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_chain_code, "b60befcc619bb1c212732770fe181f2f1aa824ab89f8aab49f2e13e3a56f0f04");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_pub_key, "036307e560072ed6ce0aa5465534fb5c258a2ccfbc257f369e8e7a181b16d897b3");
            DEFINE_NETWORK_STRING_PARAM(gait_onion, "");
            DEFINE_NETWORK_STRING_PARAM(default_peer, "192.168.56.1:19000");
            static constexpr unsigned char btc_version = 111;
            static constexpr bool main_net = false;
        };

        struct localtest_parameters final {
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_url, "ws://localhost:8080/v2/ws");
            DEFINE_NETWORK_VECTOR_STRING_PARAM(gait_wamp_cert_pins, "", "");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_address, "");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_tx, "");
            DEFINE_NETWORK_STRING_PARAM(deposit_chain_code, "");
            DEFINE_NETWORK_STRING_PARAM(deposit_pub_key, "");
            DEFINE_NETWORK_STRING_PARAM(gait_onion, "");
            DEFINE_NETWORK_STRING_PARAM(default_peer, "");
            static constexpr unsigned char btc_version = 111;
            static constexpr bool main_net = false;
        };
    }

#undef DEFINE_NETWORK_VECTOR_STRING_PARAM
#undef DEFINE_NETWORK_STRING_PARAM

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
            , _btc_version(p.btc_version)
            , _main_net(p.main_net)
        {
        }

        network_parameters(const network_parameters&) = delete;
        network_parameters& operator=(const network_parameters&) = delete;

        network_parameters(network_parameters&&) = default;
        network_parameters& operator=(network_parameters&&) = default;

        const std::string& gait_wamp_url() const { return _gait_wamp_url; }
        const std::vector<std::string>& gait_wamp_cert_pins() const { return _gait_wamp_cert_pins; }
        const std::string& block_explorer_address() const { return _block_explorer_address; }
        const std::string& block_explorer_tx() const { return _block_explorer_tx; }
        const std::string& deposit_chain_code() const { return _deposit_chain_code; }
        const std::string& deposit_pub_key() const { return _deposit_pub_key; }
        const std::string& gait_onion() const { return _gait_onion; }
        unsigned char btc_version() const { return _btc_version; }
        bool main_net() const { return _main_net; }

    private:
        std::string _gait_wamp_url;
        std::vector<std::string> _gait_wamp_cert_pins;
        std::string _block_explorer_address;
        std::string _block_explorer_tx;
        std::string _deposit_chain_code;
        std::string _deposit_pub_key;
        std::string _gait_onion;
        std::string _default_peer;
        unsigned char _btc_version;
        bool _main_net;
    };

    inline network_parameters make_localtest_network()
    {
        return network_parameters(ga::sdk::detail::localtest_parameters());
    }

    inline network_parameters make_regtest_network()
    {
        return network_parameters(ga::sdk::detail::regtest_parameters());
    }

    inline network_parameters make_testnet_network()
    {
        return network_parameters(ga::sdk::detail::testnet_parameters());
    }
}
}

#endif
