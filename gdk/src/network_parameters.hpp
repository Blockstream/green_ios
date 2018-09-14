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

        // FIXME: generate these from pem file?
        // https://www.identrust.com/certificates/trustid/root-download-x3.html
        const static char* IDENTX3 = R"(
-----BEGIN CERTIFICATE-----
MIIDSjCCAjKgAwIBAgIQRK+wgNajJ7qJMDmGLvhAazANBgkqhkiG9w0BAQUFADA/
MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT
DkRTVCBSb290IENBIFgzMB4XDTAwMDkzMDIxMTIxOVoXDTIxMDkzMDE0MDExNVow
PzEkMCIGA1UEChMbRGlnaXRhbCBTaWduYXR1cmUgVHJ1c3QgQ28uMRcwFQYDVQQD
Ew5EU1QgUm9vdCBDQSBYMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AN+v6ZdQCINXtMxiZfaQguzH0yxrMMpb7NnDfcdAwRgUi+DoM3ZJKuM/IUmTrE4O
rz5Iy2Xu/NMhD2XSKtkyj4zl93ewEnu1lcCJo6m67XMuegwGMoOifooUMM0RoOEq
OLl5CjH9UL2AZd+3UWODyOKIYepLYYHsUmu5ouJLGiifSKOeDNoJjj4XLh7dIN9b
xiqKqy69cK3FCxolkHRyxXtqqzTWMIn/5WgTe1QLyNau7Fqckh49ZLOMxt+/yUFw
7BZy1SbsOFU5Q9D8/RhcQPGX69Wam40dutolucbY38EVAjqr2m7xPi71XAicPNaD
aeQQmxkqtilX4+U9m5/wAl0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNV
HQ8BAf8EBAMCAQYwHQYDVR0OBBYEFMSnsaR7LHH62+FLkHX/xBVghYkQMA0GCSqG
SIb3DQEBBQUAA4IBAQCjGiybFwBcqR7uKGY3Or+Dxz9LwwmglSBd49lZRNI+DT69
ikugdB/OEIKcdBodfpga3csTS7MgROSR6cz8faXbauX+5v3gTt23ADq1cEmv8uXr
AvHRAosZy5Q6XkjEGB5YGV8eAlrwDPGxrancWYaLbumR9YbK+rlmM6pZW87ipxZz
R8srzJmwN0jP41ZL9c8PDHIyh8bwRLtTcm1D9SZImlJnt1ir/md2cXjbDaJWFBM5
JDGFoqgCWjBH4d1QB7wCCZAA62RjYJsWvIjJEubSfZGL+T0yjWW06XyxV3bqxbYo
Ob8VZRzI9neWagqNdwvYkQsEjgfbKbYK7p2CNTUQ
-----END CERTIFICATE-----)";

        // https://letsencrypt.org/certs/isrgrootx1.pems.txt
        const static char* LEX1 = R"(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----)";

#define DEFINE_NETWORK_STRING_PARAM(name, s)                                                                           \
    const std::string name { s }
#define DEFINE_NETWORK_VECTOR_STRING_PARAM(name, s, t)                                                                 \
    const std::vector<std::string> name { s, t }

        struct mainnet_parameters final {
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_url, "wss://prodwss.greenaddress.it/v2/ws");
            DEFINE_NETWORK_VECTOR_STRING_PARAM(gait_wamp_cert_pins,
                "25847d668eb4f04fdd40b12b6b0740c567da7d024308eb6c2c96fe41d9de218d",
                "a74b0c32b65b95fe2c4f8f098947a68b695033bed0b51dd8b984ecae89571bb6");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_address, "https://www.smartbit.com.au/address/");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_tx, "https://www.smartbit.com.au/tx/");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_chain_code, "e9a563d68686999af372a33157209c6860fe79197a4dafd9ec1dbaa49523351d");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_pub_key, "0322c5f5c9c4b9d1c3e22ca995e200d724c2d7d8b6953f7b38fddf9296053c961f");
            DEFINE_NETWORK_STRING_PARAM(gait_onion, "ws://s7a4rvc6425y72d2.onion/v2/ws/");
            DEFINE_NETWORK_STRING_PARAM(default_peer, "");
            DEFINE_NETWORK_STRING_PARAM(bech32_prefix, "bc");
            DEFINE_NETWORK_VECTOR_STRING_PARAM(gait_wamp_cert_roots, IDENTX3, LEX1);
            static constexpr unsigned char btc_version{ 0 };
            static constexpr unsigned char btc_p2sh_version{ 5 };
            static constexpr bool main_net{ true };
        };

        struct testnet_parameters final {
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_url, "wss://testwss.greenaddress.it/v2/ws");
            DEFINE_NETWORK_VECTOR_STRING_PARAM(gait_wamp_cert_pins,
                "25847d668eb4f04fdd40b12b6b0740c567da7d024308eb6c2c96fe41d9de218d",
                "a74b0c32b65b95fe2c4f8f098947a68b695033bed0b51dd8b984ecae89571bb6");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_address, "https://sandbox.smartbit.com.au/address/");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_tx, "https://sandbox.smartbit.com.au/tx/");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_chain_code, "b60befcc619bb1c212732770fe181f2f1aa824ab89f8aab49f2e13e3a56f0f04");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_pub_key, "036307e560072ed6ce0aa5465534fb5c258a2ccfbc257f369e8e7a181b16d897b3");
            DEFINE_NETWORK_STRING_PARAM(gait_onion, "ws://gu5ke7a2aguwfqhz.onion/v2/ws");
            DEFINE_NETWORK_STRING_PARAM(default_peer, "");
            DEFINE_NETWORK_STRING_PARAM(bech32_prefix, "tb");
            DEFINE_NETWORK_VECTOR_STRING_PARAM(gait_wamp_cert_roots, IDENTX3, LEX1);
            static constexpr unsigned char btc_version{ 111 };
            static constexpr unsigned char btc_p2sh_version{ 196 };
            static constexpr bool main_net{ false };
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
            DEFINE_NETWORK_STRING_PARAM(bech32_prefix, "bcrt");
            DEFINE_NETWORK_VECTOR_STRING_PARAM(gait_wamp_cert_roots, "", "");
            static constexpr unsigned char btc_version{ 111 };
            static constexpr unsigned char btc_p2sh_version{ 196 };
            static constexpr bool main_net{ false };
        };

        struct localtest_parameters final {
            DEFINE_NETWORK_STRING_PARAM(gait_wamp_url, "ws://localhost:8080/v2/ws");
            DEFINE_NETWORK_VECTOR_STRING_PARAM(gait_wamp_cert_pins, "", "");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_address, "");
            DEFINE_NETWORK_STRING_PARAM(block_explorer_tx, "");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_chain_code, "b60befcc619bb1c212732770fe181f2f1aa824ab89f8aab49f2e13e3a56f0f04");
            DEFINE_NETWORK_STRING_PARAM(
                deposit_pub_key, "036307e560072ed6ce0aa5465534fb5c258a2ccfbc257f369e8e7a181b16d897b3");
            DEFINE_NETWORK_STRING_PARAM(gait_onion, "");
            DEFINE_NETWORK_STRING_PARAM(default_peer, "");
            DEFINE_NETWORK_STRING_PARAM(bech32_prefix, "bcrt");
            DEFINE_NETWORK_VECTOR_STRING_PARAM(gait_wamp_cert_roots, "", "");
            static constexpr unsigned char btc_version{ 111 };
            static constexpr unsigned char btc_p2sh_version{ 196 };
            static constexpr bool main_net{ false };
        };
    } // namespace detail

#undef DEFINE_NETWORK_VECTOR_STRING_PARAM
#undef DEFINE_NETWORK_STRING_PARAM

    class network_parameters final {
    public:
        template <typename params>
        explicit network_parameters(params p, std::string proxy = std::string(), bool use_tor = false)
            : m_gait_wamp_url{ p.gait_wamp_url }
            , m_gait_wamp_cert_pins{ p.gait_wamp_cert_pins }
            , m_gait_wamp_cert_roots{ p.gait_wamp_cert_roots }
            , m_block_explorer_address{ p.block_explorer_address }
            , m_block_explorer_tx{ p.block_explorer_tx }
            , m_chain_code{ p.deposit_chain_code }
            , m_pub_key{ p.deposit_pub_key }
            , m_gait_onion{ p.gait_onion }
            , m_default_peer{ p.default_peer }
            , m_proxy{ std::move(proxy) }
            , m_bech32_prefix{ p.bech32_prefix }
            , m_btc_version{ p.btc_version }
            , m_btc_p2sh_version{ p.btc_p2sh_version }
            , m_main_net{ p.main_net }
            , m_use_tor{ use_tor }
        {
        }

        ~network_parameters() = default;

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
        const std::string& bech32_prefix() const { return m_bech32_prefix; }
        const std::string& get_proxy() const { return m_proxy; }
        unsigned char btc_version() const { return m_btc_version; }
        unsigned char btc_p2sh_version() const { return m_btc_p2sh_version; }
        bool main_net() const { return m_main_net; }
        bool get_use_tor() const { return m_use_tor; }

    private:
        std::string m_gait_wamp_url;
        std::vector<std::string> m_gait_wamp_cert_pins;
        std::vector<std::string> m_gait_wamp_cert_roots;
        std::string m_block_explorer_address;
        std::string m_block_explorer_tx;
        std::string m_chain_code;
        std::string m_pub_key;
        std::string m_gait_onion;
        std::string m_default_peer;
        std::string m_proxy;
        std::string m_bech32_prefix;
        unsigned char m_btc_version;
        unsigned char m_btc_p2sh_version;
        bool m_main_net;
        bool m_use_tor;
    };

    inline network_parameters make_localtest_network(const std::string& proxy = std::string(), bool use_tor = false)
    {
        return network_parameters{ ga::sdk::detail::localtest_parameters{}, proxy, use_tor };
    }

    inline network_parameters make_regtest_network(const std::string& proxy = std::string(), bool use_tor = false)
    {
        return network_parameters{ ga::sdk::detail::regtest_parameters{}, proxy, use_tor };
    }

    inline network_parameters make_testnet_network(const std::string& proxy = std::string(), bool use_tor = false)
    {
        return network_parameters{ ga::sdk::detail::testnet_parameters{}, proxy, use_tor };
    }

    inline network_parameters make_mainnet_network(const std::string& proxy = std::string(), bool use_tor = false)
    {
        return network_parameters{ ga::sdk::detail::mainnet_parameters{}, proxy, use_tor };
    }
} // namespace sdk
} // namespace ga

#endif
