#ifndef GA_SDK_NETWORK_PARAMETERS_HPP
#define GA_SDK_NETWORK_PARAMETERS_HPP
#pragma once

#include <memory>
#include <string>
#include <vector>

namespace ga {
namespace sdk {

    class GASDK_API network_parameters final {
    public:
        static void add(const std::string& name, const nlohmann::json& params);

        static std::shared_ptr<network_parameters> get(
            const std::string& name, const std::string& proxy = std::string(), bool use_tor = false);

        network_parameters(const nlohmann::json& details, std::string proxy = std::string(), bool use_tor = false);

        ~network_parameters();

        network_parameters(const network_parameters&) = delete;
        network_parameters& operator=(const network_parameters&) = delete;

        network_parameters(network_parameters&&) = default;
        network_parameters& operator=(network_parameters&&) = default;

        const std::string& gait_wamp_url() const { return m_gait_wamp_url; }
        const std::vector<std::string>& gait_wamp_cert_pins() const { return m_gait_wamp_cert_pins; }
        const std::vector<std::string>& gait_wamp_cert_roots() const { return m_gait_wamp_cert_roots; }
        const std::string& block_explorer_address() const { return m_block_explorer_address; }
        const std::string& block_explorer_tx() const { return m_block_explorer_tx; }
        const std::string& chain_code() const { return m_chain_code; }
        const std::string& pub_key() const { return m_pub_key; }
        const std::string& gait_onion() const { return m_gait_onion; }
        const std::vector<std::string>& default_peers() const { return m_default_peers; }
        const std::string& bech32_prefix() const { return m_bech32_prefix; }
        const std::string& get_proxy() const { return m_proxy; }
        unsigned char btc_version() const { return m_btc_version; }
        unsigned char btc_p2sh_version() const { return m_btc_p2sh_version; }
        bool main_net() const { return m_main_net; }
        const std::string& get_connection_string() const { return m_use_tor ? m_gait_onion : m_gait_wamp_url; }

    private:
        std::string m_gait_wamp_url;
        std::vector<std::string> m_gait_wamp_cert_pins;
        std::vector<std::string> m_gait_wamp_cert_roots;
        std::string m_block_explorer_address;
        std::string m_block_explorer_tx;
        std::string m_chain_code;
        std::string m_pub_key;
        std::string m_gait_onion;
        std::vector<std::string> m_default_peers;
        std::string m_proxy;
        std::string m_bech32_prefix;
        unsigned char m_btc_version;
        unsigned char m_btc_p2sh_version;
        bool m_main_net;
        bool m_use_tor;
    };
} // namespace sdk
} // namespace ga

#endif
