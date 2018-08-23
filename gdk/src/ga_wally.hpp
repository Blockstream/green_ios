#ifndef GA_SDK_CORE_WALLY_HPP
#define GA_SDK_CORE_WALLY_HPP
#pragma once

#include "assertion.hpp"
#include <wally.hpp>

/* These wrappers allow passing containers such as std::vector, std::array,
 * std::string and custom classes as input/output buffers to wally functions.
 */
namespace ga {
namespace sdk {

    namespace detail {
        struct string_dtor {
            void operator()(char* p) { ::wally::free_string(p); }
        };
        inline std::string make_string(char* p)
        {
            return std::string(std::unique_ptr<char, detail::string_dtor>(p).get());
        }
    } // namespace detail

#ifdef __GNUC__
#define GA_USE_RESULT __attribute__((warn_unused_result))
#else
#define GA_USE_RESULT
#endif

#define SDK_FN_3(F)                                                                                                    \
    inline void F(uint32_t i321) { GA_SDK_VERIFY(wally::F(i321)); }

#define SDK_FN_333_BBBBBA(F)                                                                                           \
    template <class I1, class I2, class I3, class I4, class I5, class O>                                               \
    inline void F(uint32_t i321, uint32_t i322, uint32_t i323, const I1& i1, const I2& i2, const I3& i3, const I4& i4, \
        const I5& i5, O** out)                                                                                         \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i321, i322, i323, i1, i2, i3, i4, i5, out));                                            \
    }

#define SDK_FN_33SS_A(F)                                                                                               \
    template <class O> inline void F(uint32_t i321, uint32_t i322, size_t s1, size_t s2, O** out)                      \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i321, i322, s1, s2, out));                                                              \
    }

#define SDK_FN_3_A(F)                                                                                                  \
    template <class O> inline void F(uint32_t i321, O** out) { GA_SDK_VERIFY(wally::F(i321, out)); }

#define SDK_FN_6B_A(F)                                                                                                 \
    template <class I1, class O> inline void F(uint64_t i641, const I1& i1, O** out)                                   \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i641, i1, out));                                                                        \
    }

#define SDK_FN_B(F)                                                                                                    \
    template <class I> inline void F(const I& i1) { GA_SDK_VERIFY(wally::F(i1)); }

#define SDK_FN_B33BP_A(F)                                                                                              \
    template <class I1, class I2, class P1, class O>                                                                   \
    inline void F(const I1& i1, uint32_t i321, uint32_t i322, const I2& i2, const P1& p1, O** out)                     \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i1, i321, i322, i2, p1, out));                                                          \
    }

#define SDK_FN_B33_A(F)                                                                                                \
    template <class I1, class O> inline void F(const I1& i1, uint32_t i321, uint32_t i322, O** out)                    \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i1, i321, i322, out));                                                                  \
    }

#define SDK_FN_B33_BS(F)                                                                                               \
    template <class I1, class O> GA_USE_RESULT inline size_t F(const I1& i1, uint32_t i321, uint32_t i322, O& out)     \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(i1, i321, i322, out, &written));                                                        \
        return written;                                                                                                \
    }

#define SDK_FN_B33_P(F)                                                                                                \
    template <class I1, class O> inline void F(const I1& i1, uint32_t i321, uint32_t i322, O* out)                     \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i1, i321, i322, out));                                                                  \
    }

#define SDK_FN_B3_A(F)                                                                                                 \
    template <class I1, class O> inline void F(const I1& i1, uint32_t i321, O** out)                                   \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i1, i321, out));                                                                        \
    }

#define SDK_FN_B3_C(F)                                                                                                 \
    template <class I1> inline std::string F(const I1& i1, uint32_t i321)                                              \
    {                                                                                                                  \
        char* ret;                                                                                                     \
        GA_SDK_VERIFY(wally::F(i1, i321, &ret));                                                                       \
        return detail::make_string(ret);                                                                               \
    }

#define SDK_FN_B3_BS(F)                                                                                                \
    template <class I1, class O> GA_USE_RESULT inline size_t F(const I1& i1, uint32_t i321, O& out)                    \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(i1, i321, out, &written));                                                              \
        return written;                                                                                                \
    }

#define SDK_FN_BB333_B(F)                                                                                              \
    template <class I1, class I2, class O>                                                                             \
    inline void F(const I1& i1, const I2& i2, uint32_t i321, uint32_t i322, uint32_t i323, O& out)                     \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i1, i2, i321, i322, i323, out));                                                        \
    }

#define SDK_FN_BB3_A(F)                                                                                                \
    template <class I1, class I2, class O> inline void F(const I1& i1, const I2& i2, uint32_t i321, O** out)           \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i1, i2, i321, out));                                                                    \
    }

#define SDK_FN_BB3_B(F)                                                                                                \
    template <class I1, class I2, class O> inline void F(const I1& i1, const I2& i2, uint32_t i321, O& out)            \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i1, i2, i321, out));                                                                    \
    }

#define SDK_FN_BB3_BS(F)                                                                                               \
    template <class I1, class I2, class O>                                                                             \
    GA_USE_RESULT inline size_t F(const I1& i1, const I2& i2, uint32_t i321, O& out)                                   \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(i1, i2, i321, out, &written));                                                          \
        return written;                                                                                                \
    }

#define SDK_FN_BBB3_BS(F)                                                                                              \
    template <class I1, class I2, class I3, class O>                                                                   \
    GA_USE_RESULT inline size_t F(const I1& i1, const I2& i2, const I3& i3, uint32_t i321, O& out)                     \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(i1, i2, i3, i321, out, &written));                                                      \
        return written;                                                                                                \
    }

#define SDK_FN_BB_B(F)                                                                                                 \
    template <class I1, class I2, class O> inline void F(const I1& i1, const I2& i2, O& out)                           \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i1, i2, out));                                                                          \
    }

#define SDK_FN_BP3_A(F)                                                                                                \
    template <class I1, class P1, class O> inline void F(const I1& i1, const P1& p1, uint32_t i321, O** out)           \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i1, p1, i321, out));                                                                    \
    }

#define SDK_FN_BB_BS(F)                                                                                                \
    template <class I1, class I2, class O> GA_USE_RESULT inline size_t F(const I1& i1, const I2& i2, O& out)           \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(i1, i2, out, &written));                                                                \
        return written;                                                                                                \
    }

#define SDK_FN_B_A(F)                                                                                                  \
    template <class I1, class O> inline void F(const I1& i1, O** out) { GA_SDK_VERIFY(wally::F(i1, out)); }

#define SDK_FN_B_B(F)                                                                                                  \
    template <class I, class O> inline void F(const I& i1, O& out) { GA_SDK_VERIFY(wally::F(i1, out)); }

#define SDK_FN_B_C(F)                                                                                                  \
    template <class I1> inline std::string F(const I1& i1)                                                             \
    {                                                                                                                  \
        char* ret;                                                                                                     \
        GA_SDK_VERIFY(wally::F(i1, &ret));                                                                             \
        return detail::make_string(ret);                                                                               \
    }

#define SDK_FN_B_BS(F)                                                                                                 \
    template <class I, class O> GA_USE_RESULT inline size_t F(const I& i1, O& out)                                     \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(i1, out, &written));                                                                    \
        return written;                                                                                                \
    }

#define SDK_FN_B_P(F)                                                                                                  \
    template <class I1, class O> inline void F(const I1& i1, O* out) { GA_SDK_VERIFY(wally::F(i1, out)); }

#define SDK_FN_B_S(F)                                                                                                  \
    template <class I> GA_USE_RESULT inline size_t F(const I& i1)                                                      \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(i1, &written));                                                                         \
        return written;                                                                                                \
    }

#define SDK_FN_BB33_B(F)                                                                                               \
    template <class I1, class I2, class O>                                                                             \
    inline void F(const I1& i1, const I2& i2, uint32_t i321, uint32_t i322, O& out)                                    \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(i1, i2, i321, i322, out));                                                              \
    }

#define SDK_FN_P(F)                                                                                                    \
    template <class P1> inline void F(const P1& p1) { GA_SDK_VERIFY(wally::F(p1)); }

#define SDK_FN_P3(F)                                                                                                   \
    template <class P1> inline void F(const P1& p1, uint32_t i321) { GA_SDK_VERIFY(wally::F(p1, i321)); }

#define SDK_FN_P33(F)                                                                                                  \
    template <class P1> inline void F(const P1& p1, uint32_t i321, uint32_t i322)                                      \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i321, i322));                                                                       \
    }

#define SDK_FN_P33_P(F)                                                                                                \
    template <class P1, class O> inline void F(const P1& p1, uint32_t i321, uint32_t i322, O* out)                     \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i321, i322, out));                                                                  \
    }

#define SDK_FN_P3B(F)                                                                                                  \
    template <class P1, class I1, class O> inline void F(const P1& p1, uint32_t i321, const I1& i1, O& out)            \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i321, i1, out));                                                                    \
    }

#define SDK_FN_P3B633_B(F)                                                                                             \
    template <class P1, class I1, class O>                                                                             \
    inline void F(const P1& p1, uint32_t i321, const I1& i1, uint64_t i641, uint32_t i322, uint32_t i323, O& out)      \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i321, i1, i641, i322, i323, out));                                                  \
    }

#define SDK_FN_P3BB36333_B(F)                                                                                          \
    template <class P1, class I1, class I2, class O>                                                                   \
    inline void F(const P1& p1, uint32_t i321, const I1& i1, const I2& i2, uint32_t i322, uint64_t i641,               \
        uint32_t i323, uint32_t i324, uint32_t i325, O& out)                                                           \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i321, i1, i2, i322, i641, i323, i324, i325, out));                                  \
    }

#define SDK_FN_P3_A(F)                                                                                                 \
    template <class P1, class O> inline void F(const P1& p1, uint32_t i321, O** out)                                   \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i321, out));                                                                        \
    }

#define SDK_FN_P3_B(F)                                                                                                 \
    template <class P1, class O> inline void F(const P1& p1, uint32_t i321, O& out)                                    \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i321, out));                                                                        \
    }

#define SDK_FN_P3_BS(F)                                                                                                \
    template <class P1, class O> GA_USE_RESULT inline size_t F(const P1& p1, uint32_t i321, O& out)                    \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(p1, i321, out, &written));                                                              \
        return written;                                                                                                \
    }

#define SDK_FN_P3_S(F)                                                                                                 \
    template <class P1> GA_USE_RESULT inline size_t F(const P1& p1, uint32_t i321)                                     \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(p1, i321, &written));                                                                   \
        return written;                                                                                                \
    }

#define SDK_FN_P6B3(F)                                                                                                 \
    template <class P1, class I1> inline void F(const P1& p1, uint64_t i641, const I1& i1, uint32_t i321)              \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i641, i1, i321));                                                                   \
    }

#define SDK_FN_PB(F)                                                                                                   \
    template <class P1, class I1> inline void F(const P1& p1, const I1& i1) { GA_SDK_VERIFY(wally::F(p1, i1)); }

#define SDK_FN_PB33BP3(F)                                                                                              \
    template <class P1, class I1, class I2, class P2>                                                                  \
    inline void F(const P1& p1, const I1& i1, uint32_t i321, uint32_t i322, const I2& i2, const P2& p2, uint32_t i323) \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i1, i321, i322, i2, p2, i323));                                                     \
    }

#define SDK_FN_PB3_A(F)                                                                                                \
    template <class P1, class I1, class O> inline void F(const P1& p1, const I1& i1, uint32_t i321, O** out)           \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i1, i321, out));                                                                    \
    }

#define SDK_FN_PB3_B(F)                                                                                                \
    template <class P1, class I1, class O> inline void F(const P1& p1, const I1& i1, uint32_t i321, O& out)            \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i1, i321, out));                                                                    \
    }

#define SDK_FN_PB3_P(F)                                                                                                \
    template <class P1, class I1, class O> inline void F(const P1& p1, const I1& i1, uint32_t i321, O* out)            \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i1, i321, out));                                                                    \
    }

#define SDK_FN_PB_A(F)                                                                                                 \
    template <class P1, class I1, class O> inline void F(const P1& p1, const I1& i1, O** out)                          \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, i1, out));                                                                          \
    }

#define SDK_FN_PP(F)                                                                                                   \
    template <class P1, class P2> inline void F(const P1& p1, const P2& p2) { GA_SDK_VERIFY(wally::F(p1, p2)); }

#define SDK_FN_PP3_BS(F)                                                                                               \
    template <class P1, class P2, class O>                                                                             \
    GA_USE_RESULT inline size_t F(const P1& p1, const P2& p2, uint32_t i321, O& out)                                   \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(p1, p2, i321, out, &written));                                                          \
        return written;                                                                                                \
    }

#define SDK_FN_PP_BS(F)                                                                                                \
    template <class P1, class P2, class O> GA_USE_RESULT inline size_t F(const P1& p1, const P2& p2, O& out)           \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(p1, p2, out, &written));                                                                \
        return written;                                                                                                \
    }

#define SDK_FN_PS(F)                                                                                                   \
    template <class P1> inline void F(const P1& p1, size_t s1) { GA_SDK_VERIFY(wally::F(p1, s1)); }

#define SDK_FN_PSB(F)                                                                                                  \
    template <class P1, class I1> inline void F(const P1& p1, size_t s1, const I1& i1)                                 \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, s1, i1));                                                                           \
    }

#define SDK_FN_PSP(F)                                                                                                  \
    template <class P1, class P2> inline void F(const P1& p1, size_t s1, const P2& p2)                                 \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, s1, p2));                                                                           \
    }

#define SDK_FN_PS_A(F)                                                                                                 \
    template <class P1, class O> inline void F(const P1& p1, size_t s1, O** out)                                       \
    {                                                                                                                  \
        GA_SDK_VERIFY(wally::F(p1, s1, out));                                                                          \
    }

#define SDK_FN_P_A(F)                                                                                                  \
    template <class P1, class O> inline void F(const P1& p1, O** out) { GA_SDK_VERIFY(wally::F(p1, out)); }

#define SDK_FN_P_BS(F)                                                                                                 \
    template <class P1, class O> GA_USE_RESULT inline size_t F(const P1& p1, O& out)                                   \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(p1, out, &written));                                                                    \
        return written;                                                                                                \
    }

#define SDK_FN_P_S(F)                                                                                                  \
    template <class P1> GA_USE_RESULT inline size_t F(const P1& p1)                                                    \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(p1, &written));                                                                         \
        return written;                                                                                                \
    }

#define SDK_FN_S_S(F)                                                                                                  \
    GA_USE_RESULT inline size_t F(size_t s1)                                                                           \
    {                                                                                                                  \
        size_t written;                                                                                                \
        GA_SDK_VERIFY(wally::F(s1, &written));                                                                         \
        return written;                                                                                                \
    }

    SDK_FN_3(init)
    SDK_FN_3(cleanup)
    SDK_FN_333_BBBBBA(bip32_key_init_alloc)
    SDK_FN_33SS_A(tx_init_alloc)
    SDK_FN_3_A(tx_witness_stack_init_alloc)
    SDK_FN_6B_A(tx_output_init_alloc)
    SDK_FN_B(ec_private_key_verify)
    SDK_FN_B(secp_randomize)
    SDK_FN_B33BP_A(tx_input_init_alloc)
    SDK_FN_B33_A(bip32_key_from_parent_alloc)
    SDK_FN_B33_A(bip32_key_from_seed_alloc)
    SDK_FN_B33_BS(scriptpubkey_csv_2of2_then_1_from_bytes)
    SDK_FN_B33_BS(scriptpubkey_csv_2of3_then_2_from_bytes)
    SDK_FN_B33_BS(scriptpubkey_multisig_from_bytes)
    SDK_FN_B33_P(bip32_key_from_seed)
    SDK_FN_B3_A(tx_from_bytes)
    SDK_FN_B3_BS(format_bitcoin_message)
    SDK_FN_B3_BS(script_push_from_bytes)
    SDK_FN_B3_BS(scriptpubkey_p2pkh_from_bytes)
    SDK_FN_B3_BS(scriptpubkey_p2sh_from_bytes)
    SDK_FN_B3_BS(witness_program_from_bytes)
    SDK_FN_B3_C(base58_from_bytes)
    SDK_FN_BB333_B(scrypt)
    SDK_FN_BB3_A(bip38_from_private_key)
    SDK_FN_BB3_B(aes)
    SDK_FN_BB3_B(bip38_raw_from_private_key)
    SDK_FN_BB3_B(bip38_raw_to_private_key)
    SDK_FN_BB3_B(ec_sig_from_bytes)
    SDK_FN_BB3_B(ec_sig_verify)
    SDK_FN_BB3_BS(scriptsig_p2pkh_from_sig)
    SDK_FN_BBB3_BS(aes_cbc)
    SDK_FN_BBB3_BS(scriptsig_multisig_from_bytes)
    SDK_FN_BB_B(hmac_sha256)
    SDK_FN_BB_B(hmac_sha512)
    SDK_FN_BP3_A(addr_segwit_from_bytes)
    SDK_FN_BB_BS(scriptsig_p2pkh_from_der)
    SDK_FN_B_A(bip32_key_unserialize_alloc)
    SDK_FN_B_B(ec_public_key_decompress)
    SDK_FN_B_B(ec_public_key_from_private_key)
    SDK_FN_B_B(ec_sig_from_der)
    SDK_FN_B_B(ec_sig_normalize)
    SDK_FN_B_B(hash160)
    SDK_FN_B_B(sha256)
    SDK_FN_B_B(sha256d)
    SDK_FN_B_B(sha512)
    SDK_FN_B_BS(ec_sig_to_der)
    SDK_FN_B_C(hex_from_bytes)
    SDK_FN_B_P(bip32_key_unserialize)
    SDK_FN_B_S(scriptpubkey_get_type)
    SDK_FN_BB33_B(pbkdf2_hmac_sha256)
    SDK_FN_BB33_B(pbkdf2_hmac_sha512)
    SDK_FN_P(bip32_key_free)
    SDK_FN_P(get_operations)
    SDK_FN_P(set_operations)
    SDK_FN_P(tx_free)
    SDK_FN_P(tx_input_free)
    SDK_FN_P(tx_output_free)
    SDK_FN_P(tx_witness_stack_free)
    SDK_FN_P3(tx_witness_stack_add_dummy)
    SDK_FN_P3(tx_witness_stack_set_dummy)
    SDK_FN_P33_P(bip32_key_from_parent)
    SDK_FN_P3B(tx_witness_stack_set)
    SDK_FN_P3B633_B(tx_get_btc_signature_hash)
    SDK_FN_P3BB36333_B(tx_get_signature_hash)
    SDK_FN_P3_A(tx_from_hex)
    SDK_FN_P3_A(tx_to_hex)
    SDK_FN_P3_B(bip32_key_serialize)
    SDK_FN_P3_BS(base58_to_bytes)
    SDK_FN_P3_BS(tx_to_bytes)
    SDK_FN_P3_S(tx_get_length)
    SDK_FN_P6B3(tx_add_raw_output)
    SDK_FN_PB(tx_witness_stack_add)
    SDK_FN_PB33BP3(tx_add_raw_input)
    SDK_FN_PB3_A(bip32_key_from_parent_path_alloc)
    SDK_FN_PB3_B(bip38_to_private_key)
    SDK_FN_PB3_P(bip32_key_from_parent_path)
    SDK_FN_PB_A(bip39_mnemonic_from_bytes)
    SDK_FN_PP(bip39_mnemonic_validate)
    SDK_FN_PP(tx_add_input)
    SDK_FN_PP(tx_add_output)
    SDK_FN_PP3_BS(addr_segwit_to_bytes)
    SDK_FN_PP_BS(bip39_mnemonic_to_bytes)
    SDK_FN_PP_BS(bip39_mnemonic_to_seed)
    SDK_FN_PS(tx_remove_input)
    SDK_FN_PS(tx_remove_output)
    SDK_FN_PSB(tx_set_input_script)
    SDK_FN_PSP(tx_set_input_witness)
    SDK_FN_PS_A(bip39_get_word)
    SDK_FN_P_A(bip39_get_languages)
    SDK_FN_P_A(bip39_get_wordlist)
    SDK_FN_P_BS(hex_to_bytes)
    SDK_FN_P_S(base58_get_length)
    SDK_FN_P_S(tx_get_vsize)
    SDK_FN_P_S(tx_get_weight)
    SDK_FN_P_S(tx_get_witness_count)
    SDK_FN_S_S(tx_vsize_from_weight)

    template <class I1> inline std::string base58check_from_bytes(const I1& i1)
    {
        return base58_from_bytes(i1, BASE58_FLAG_CHECKSUM);
    }

    template <class I1> inline const std::vector<unsigned char> ec_sig_to_der(const I1& sig, bool sighash = false)
    {
        std::vector<unsigned char> der(EC_SIGNATURE_DER_MAX_LEN + (sighash ? 1 : 0));
        const size_t written = ec_sig_to_der(sig, der);
        GA_SDK_RUNTIME_ASSERT(written <= der.size());
        der.resize(written);
        if (sighash) {
            der.push_back(WALLY_SIGHASH_ALL);
        }
        return der;
    }
} // namespace sdk
} // namespace ga

namespace std {
template <> struct default_delete<struct ext_key> {
    void operator()(struct ext_key* ptr) const { ::ga::sdk::bip32_key_free(ptr); }
};

template <> struct default_delete<struct wally_tx_input> {
    void operator()(struct wally_tx_input* ptr) const { ::ga::sdk::tx_input_free(ptr); }
};

template <> struct default_delete<struct wally_tx_witness_stack> {
    void operator()(struct wally_tx_witness_stack* ptr) const { ::ga::sdk::tx_witness_stack_free(ptr); }
};

template <> struct default_delete<struct wally_tx_output> {
    void operator()(struct wally_tx_output* ptr) const { ::ga::sdk::tx_output_free(ptr); }
};

template <> struct default_delete<struct wally_tx> {
    void operator()(struct wally_tx* ptr) const { ::ga::sdk::tx_free(ptr); }
};
} // namespace std

namespace ga {
namespace sdk {
    using wally_ext_key_ptr = std::unique_ptr<struct ext_key>;
    using wally_tx_input_ptr = std::unique_ptr<struct wally_tx_input>;
    using wally_tx_witness_stack_ptr = std::unique_ptr<struct wally_tx_witness_stack>;
    using wally_tx_output_ptr = std::unique_ptr<struct wally_tx_output>;
    using wally_tx_ptr = std::unique_ptr<struct wally_tx>;

    inline wally_tx_witness_stack_ptr tx_witness_stack_init(size_t allocation_len)
    {
        struct wally_tx_witness_stack* p;
        tx_witness_stack_init_alloc(allocation_len, &p);
        return wally_tx_witness_stack_ptr(p);
    }

    inline wally_tx_ptr tx_init(uint32_t locktime, size_t inputs_allocation_len, size_t outputs_allocation_len = 2,
        uint32_t version = WALLY_TX_VERSION_2)
    {
        struct wally_tx* p;
        tx_init_alloc(version, locktime, inputs_allocation_len, outputs_allocation_len, &p);
        return wally_tx_ptr(p);
    }

    inline wally_tx_ptr tx_from_hex(const std::string& tx_hex, uint32_t flags)
    {
        struct wally_tx* p;
        tx_from_hex(tx_hex, flags, &p);
        return wally_tx_ptr(p);
    }

#undef GA_USE_RESULT

} /* namespace sdk */
} /* namespace ga */

#endif /* GA_SDK_CORE_WALLY_HPP */
