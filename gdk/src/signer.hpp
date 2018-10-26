#ifndef GA_SDK_SIGNER_HPP
#define GA_SDK_SIGNER_HPP
#pragma once

#include <gsl/span>

#include "ga_wally.hpp"
#include "include/network_parameters.hpp"
#include "memory.hpp"

namespace ga {
namespace sdk {

    //
    // Interface to signing and deriving privately derived xpub keys
    //
    class signer {
    public:
        signer(const network_parameters& net_params);

        signer(const signer&) = default;
        signer& operator=(const signer&) = default;
        signer(signer&&) = default;
        signer& operator=(signer&&) = default;
        virtual ~signer();

        // Get the challenge to sign for GA authentication
        virtual std::string get_challenge() = 0;

        // Returns true if if this signer produces only low-r signatures
        virtual bool supports_low_r() const;

        // Get the xpub for 'm/<path>'. This should only be used to derive the master
        // xpub for privately derived master keys, since it may involve talking to
        // hardware. Use xpub_hdkeys_base to quickly derive from the resulting key.
        virtual xpub_t get_xpub(gsl::span<const uint32_t> path = empty_span<uint32_t>()) = 0;
        virtual std::string get_bip32_xpub(gsl::span<const uint32_t> path) = 0;

        // Return the ECDSA signature for a hash using the bip32 key 'm/<path>'
        virtual ecdsa_sig_t sign_hash(gsl::span<const uint32_t> path, gsl::span<const unsigned char> hash) = 0;

    protected:
        const network_parameters& m_net_params;
    };

    //
    // A signer that signs using a private key held in memory
    //
    class software_signer final : public signer {
    public:
        // FIXME: Take mnemonic/xpub as a char* to avoid copying
        software_signer(const network_parameters& net_params, const std::string& mnemonic_or_xpub);

        software_signer(const software_signer&) = delete;
        software_signer& operator=(const software_signer&) = delete;
        software_signer(software_signer&&) = delete;
        software_signer& operator=(software_signer&&) = delete;
        virtual ~software_signer();

        bool supports_low_r() const override;

        std::string get_challenge() override;

        xpub_t get_xpub(gsl::span<const uint32_t> path = empty_span<uint32_t>()) override;
        std::string get_bip32_xpub(gsl::span<const uint32_t> path) override;

        ecdsa_sig_t sign_hash(gsl::span<const uint32_t> path, gsl::span<const unsigned char> hash) override;

    private:
        wally_ext_key_ptr m_master_key;
    };

    //
    // A proxy for a hardware signer controlled by the caller
    //
    class hardware_signer final : public signer {
    public:
        // FIXME: Take mnemonic/xpub as a char* to avoid copying
        hardware_signer(const network_parameters& net_params, const nlohmann::json& hw_device);

        hardware_signer(const hardware_signer&) = delete;
        hardware_signer& operator=(const hardware_signer&) = delete;
        hardware_signer(hardware_signer&&) = delete;
        hardware_signer& operator=(hardware_signer&&) = delete;
        virtual ~hardware_signer();

        bool supports_low_r() const override;

        std::string get_challenge() override;

        xpub_t get_xpub(gsl::span<const uint32_t> path = empty_span<uint32_t>()) override;
        std::string get_bip32_xpub(gsl::span<const uint32_t> path) override;

        ecdsa_sig_t sign_hash(gsl::span<const uint32_t> path, gsl::span<const unsigned char> hash) override;

    private:
        const nlohmann::json m_hw_device;
    };

} // namespace sdk
} // namespace ga

#endif
