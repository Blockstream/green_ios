#ifndef GA_SDK_XPUB_HDKEY_HPP
#define GA_SDK_XPUB_HDKEY_HPP
#pragma once

#include <gsl/span>
#include <map>

#include "ga_wally.hpp"
#include "include/network_parameters.hpp"
#include "memory.hpp"

namespace ga {
namespace sdk {

    //
    // Derives public keys from an xpub
    //
    class xpub_hdkey final {
    public:
        xpub_hdkey(bool is_main_net, const xpub_t& xpub, gsl::span<const uint32_t> path = empty_span<uint32_t>());

        xpub_hdkey(const xpub_hdkey&) = default;
        xpub_hdkey& operator=(const xpub_hdkey&) = default;
        xpub_hdkey(xpub_hdkey&&) = default;
        xpub_hdkey& operator=(xpub_hdkey&&) = default;
        ~xpub_hdkey();

        pub_key_t derive(uint32_t pointer);

    private:
        ext_key m_ext_key;
    };

    namespace detail {

        //
        // Base class for collections of xpubs
        //
        class xpub_hdkeys_base {
        public:
            xpub_hdkeys_base(const network_parameters& net_params);
            xpub_hdkeys_base(const network_parameters& net_params, const xpub_t& xpub);

            xpub_hdkeys_base(const xpub_hdkeys_base&) = default;
            xpub_hdkeys_base& operator=(const xpub_hdkeys_base&) = default;
            xpub_hdkeys_base(xpub_hdkeys_base&&) = default;
            xpub_hdkeys_base& operator=(xpub_hdkeys_base&&) = default;
            virtual ~xpub_hdkeys_base() = default;

            pub_key_t derive(uint32_t subaccount, uint32_t pointer);

        protected:
            virtual xpub_hdkey get_subaccount(uint32_t subaccount) = 0;

            bool m_is_main_net;
            xpub_t m_xpub;
            std::map<uint32_t, xpub_hdkey> m_subaccounts;
        };
    } // namespace detail

    //
    // Derives GA public keys for the given network:
    // Main account
    //     m/1/gait_path/pointer
    // Subaccounts:
    //     m/3/gait_path/subaccount/pointer
    //
    class ga_pubkeys : public detail::xpub_hdkeys_base {
    public:
        ga_pubkeys(const network_parameters& net_params, gsl::span<const uint32_t> gait_path);

        ga_pubkeys(const ga_pubkeys&) = default;
        ga_pubkeys& operator=(const ga_pubkeys&) = default;
        ga_pubkeys(ga_pubkeys&&) = default;
        ga_pubkeys& operator=(ga_pubkeys&&) = default;
        virtual ~ga_pubkeys() = default;

        // Return the path that must be used to deriving the gait_path xpub
        static std::array<uint32_t, 1> get_gait_generation_path();

        // Return a gait path for registration. xpub must be the users m/0x4741' path.
        static std::array<unsigned char, HMAC_SHA512_LEN> get_gait_path_bytes(const xpub_t& xpub);

    private:
        xpub_hdkey get_subaccount(uint32_t subaccount) override;

        std::array<uint32_t, 32> m_gait_path;
    };

    //
    // Derives GA user public keys for the given network:
    // Main account:
    //     m/1/pointer
    // Subaccounts:
    //     m/3'/subaccount'/1/pointer
    // Because subaccount keys are privately derived, you must call add_subaccount
    // passing the xpub of the m/3'/subaccount' key before calling derive()
    // on a subaccount.
    //
    class ga_user_pubkeys : public detail::xpub_hdkeys_base {
    public:
        ga_user_pubkeys(const network_parameters& net_params);
        ga_user_pubkeys(const network_parameters& net_params, const xpub_t& xpub);

        ga_user_pubkeys(const ga_user_pubkeys&) = default;
        ga_user_pubkeys& operator=(const ga_user_pubkeys&) = default;
        ga_user_pubkeys(ga_user_pubkeys&&) = default;
        ga_user_pubkeys& operator=(ga_user_pubkeys&&) = default;
        virtual ~ga_user_pubkeys() = default;

        static std::vector<uint32_t> get_full_path(uint32_t subaccount, uint32_t pointer);

        bool have_subaccount(uint32_t subaccount);

        void add_subaccount(uint32_t subaccount, const xpub_t& xpub);

    private:
        xpub_hdkey get_subaccount(uint32_t subaccount) override;
    };

    //
    // User recovery keys for the given network:
    // Subaccounts:
    //     m/1/pointer
    // Recovery keys are not privately derived because the server must derive
    // keys for address generation, and it only ever has the xpub
    // representing "m". Where a recovery mnemonic is generated on the client
    // side, it encodes "m" directly.
    //

} // namespace sdk
} // namespace ga

#endif
