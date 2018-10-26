#include "signer.hpp"
#include "utils.hpp"

namespace ga {
namespace sdk {
    signer::signer(const network_parameters& net_params)
        : m_net_params(net_params)
    {
    }

    signer::~signer() {}

    bool signer::supports_low_r() const
    {
        return false; // assume not unless overridden
    }

    namespace {
        static wally_ext_key_ptr derive(const wally_ext_key_ptr& hdkey, gsl::span<const uint32_t> path)
        {
            // FIXME: Private keys should be derived into mlocked memory
            return bip32_key_from_parent_path_alloc(hdkey, path, BIP32_FLAG_KEY_PRIVATE | BIP32_FLAG_SKIP_HASH);
        }
    } // namespace

    //
    // Software signer
    //
    software_signer::software_signer(const network_parameters& net_params, const std::string& mnemonic_or_xpub)
        : signer(net_params)
    {
        // FIXME: Allocate m_master_key in mlocked memory
        if (mnemonic_or_xpub.find(' ') != std::string::npos) {
            // mnemonic
            // FIXME: secure_array
            const auto seed = bip39_mnemonic_to_seed(mnemonic_or_xpub);
            const uint32_t version = m_net_params.main_net() ? BIP32_VER_MAIN_PRIVATE : BIP32_VER_TEST_PRIVATE;
            m_master_key = bip32_key_from_seed_alloc(seed, version, 0);
        } else {
            // xpub
            m_master_key = bip32_public_key_from_bip32_xpub(mnemonic_or_xpub);
        }
    }

    software_signer::~software_signer() {}

    // FIXME: derive from capabilities in some more generic fashion
    bool software_signer::supports_low_r() const { return true; }

    std::string software_signer::get_challenge()
    {
        std::array<unsigned char, 1 + sizeof(m_master_key->hash160)> vpkh;
        vpkh[0] = m_net_params.btc_version();
        std::copy(std::begin(m_master_key->hash160), std::end(m_master_key->hash160), vpkh.data() + 1);
        return base58check_from_bytes(vpkh);
    }

    xpub_t software_signer::get_xpub(gsl::span<const uint32_t> path)
    {
        wally_ext_key_ptr derived;
        ext_key* hdkey = m_master_key.get();
        if (!path.empty()) {
            derived = derive(m_master_key, path);
            hdkey = derived.get();
        }
        return make_xpub(hdkey);
    }

    std::string software_signer::get_bip32_xpub(gsl::span<const uint32_t> path)
    {
        wally_ext_key_ptr derived;
        wally_ext_key_ptr* hdkey = &m_master_key;
        if (!path.empty()) {
            derived = derive(m_master_key, path);
            hdkey = &derived;
        }
        return base58check_from_bytes(bip32_key_serialize(*hdkey, BIP32_FLAG_KEY_PUBLIC));
    }

    ecdsa_sig_t software_signer::sign_hash(gsl::span<const uint32_t> path, gsl::span<const unsigned char> hash)
    {
        wally_ext_key_ptr derived = derive(m_master_key, path);
        return ec_sig_from_bytes(gsl::make_span(derived->priv_key).subspan(1), hash);
    }

    //
    // Hardware signer
    //
    hardware_signer::hardware_signer(const network_parameters& net_params, const nlohmann::json& hw_device)
        : signer(net_params)
        , m_hw_device(hw_device)
    {
    }

    hardware_signer::~hardware_signer() {}

    bool hardware_signer::supports_low_r() const { return m_hw_device.value("supports_low_r", false); }

    std::string hardware_signer::get_challenge()
    {
        GA_SDK_RUNTIME_ASSERT(false);
        return std::string();
    }

    xpub_t hardware_signer::get_xpub(gsl::span<const uint32_t> path)
    {
        (void)path;
        GA_SDK_RUNTIME_ASSERT(false);
        return xpub_t();
    }

    std::string hardware_signer::get_bip32_xpub(gsl::span<const uint32_t> path)
    {
        (void)path;
        GA_SDK_RUNTIME_ASSERT(false);
        return std::string();
    }

    ecdsa_sig_t hardware_signer::sign_hash(gsl::span<const uint32_t> path, gsl::span<const unsigned char> hash)
    {
        (void)path;
        (void)hash;
        GA_SDK_RUNTIME_ASSERT(false);
        return ecdsa_sig_t();
    }

} // namespace sdk
} // namespace ga
