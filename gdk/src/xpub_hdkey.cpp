#include "xpub_hdkey.hpp"

namespace ga {
namespace sdk {
    namespace {
        static const uint32_t GAIT_GENERATION_PATH = harden(0x4741); // 'GA'
        static const unsigned char GAIT_GENERATION_NONCE[30] = { 'G', 'r', 'e', 'e', 'n', 'A', 'd', 'd', 'r', 'e', 's',
            's', '.', 'i', 't', ' ', 'H', 'D', ' ', 'w', 'a', 'l', 'l', 'e', 't', ' ', 'p', 'a', 't', 'h' };
    } // namespace

    xpub_hdkey::xpub_hdkey(bool is_main_net, const xpub_t& xpub, gsl::span<const uint32_t> path)
    {
        const uint32_t version = is_main_net ? BIP32_VER_MAIN_PUBLIC : BIP32_VER_TEST_PUBLIC;
        wally_ext_key_ptr master = bip32_key_init_alloc(version, 0, 0, xpub.first, xpub.second);

        if (!path.empty()) {
            m_ext_key = bip32_public_key_from_parent_path(*master, path);
        } else {
            m_ext_key = *master;
        }
    }

    xpub_hdkey::~xpub_hdkey() { wally_bzero(&m_ext_key, sizeof(m_ext_key)); }

    pub_key_t xpub_hdkey::derive(uint32_t pointer)
    {
        ext_key result = bip32_public_key_from_parent(m_ext_key, pointer);
        pub_key_t ret;
        std::copy(result.pub_key, result.pub_key + ret.size(), ret.begin());
        wally_bzero(&result, sizeof(result));
        return ret;
    }

    namespace detail {
        xpub_hdkeys_base::xpub_hdkeys_base(const network_parameters& net_params)
            : m_is_main_net(net_params.main_net())
        {
        }

        xpub_hdkeys_base::xpub_hdkeys_base(const network_parameters& net_params, const xpub_t& xpub)
            : m_is_main_net(net_params.main_net())
            , m_xpub(xpub)
        {
        }

        pub_key_t xpub_hdkeys_base::derive(uint32_t subaccount, uint32_t pointer)
        {
            return get_subaccount(subaccount).derive(pointer);
        }
    } // namespace detail

    ga_pubkeys::ga_pubkeys(const network_parameters& net_params, gsl::span<const uint32_t> gait_path)
        : detail::xpub_hdkeys_base(net_params, make_xpub(net_params.chain_code(), net_params.pub_key()))
    {
        GA_SDK_RUNTIME_ASSERT(static_cast<size_t>(gait_path.size()) == m_gait_path.size());
        std::copy(std::begin(gait_path), std::end(gait_path), m_gait_path.begin());
        get_subaccount(0); // Initialize main account
    }

    xpub_hdkey ga_pubkeys::get_subaccount(uint32_t subaccount)
    {
        const auto p = m_subaccounts.find(subaccount);
        if (p != m_subaccounts.end()) {
            return p->second;
        } else {
            const uint32_t path_prefix = subaccount != 0 ? 3 : 1;
            std::vector<uint32_t> path(m_gait_path.size() + 1);
            init_container(path, gsl::make_span(&path_prefix, 1), m_gait_path);
            if (subaccount != 0) {
                path.push_back(subaccount);
            }
            return m_subaccounts.insert(std::make_pair(subaccount, xpub_hdkey(m_is_main_net, m_xpub, path)))
                .first->second;
        }
    }

    std::array<uint32_t, 1> ga_pubkeys::get_gait_generation_path()
    {
        return std::array<uint32_t, 1>{ { GAIT_GENERATION_PATH } };
    }

    std::array<unsigned char, HMAC_SHA512_LEN> ga_pubkeys::get_gait_path_bytes(const xpub_t& xpub)
    {
        std::array<unsigned char, sizeof(chain_code_t) + sizeof(pub_key_t)> path_data;
        init_container(path_data, xpub.first, xpub.second);
        return hmac_sha512(GAIT_GENERATION_NONCE, path_data);
    }

    ga_user_pubkeys::ga_user_pubkeys(const network_parameters& net_params)
        : detail::xpub_hdkeys_base(net_params)
    {
    }

    ga_user_pubkeys::ga_user_pubkeys(const network_parameters& net_params, const xpub_t& xpub)
        : detail::xpub_hdkeys_base(net_params, xpub)
    {
        add_subaccount(0, m_xpub);
    }

    bool ga_user_pubkeys::have_subaccount(uint32_t subaccount)
    {
        return m_subaccounts.find(subaccount) != m_subaccounts.end();
    }

    void ga_user_pubkeys::add_subaccount(uint32_t subaccount, const xpub_t& xpub)
    {
        std::array<uint32_t, 1> path{ { 1 } };
        m_subaccounts.emplace(subaccount, xpub_hdkey(m_is_main_net, xpub, path));
    }

    xpub_hdkey ga_user_pubkeys::get_subaccount(uint32_t subaccount)
    {
        const auto p = m_subaccounts.find(subaccount);
        GA_SDK_RUNTIME_ASSERT(p != m_subaccounts.end());
        return p->second;
    }

} // namespace sdk
} // namespace ga
