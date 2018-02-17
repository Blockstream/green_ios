#ifndef GA_SDK_WALLY_WRAPPER_HPP
#define GA_SDK_WALLY_WRAPPER_HPP
#pragma once

#include <array>
#include <vector>
#include <wally_bip32.h>
#include <wally_bip39.h>
#include <wally_core.h>
#include <wally_crypto.h>
#include <wally_script.h>
#include <wally_transaction.h>

/* These wrappers allow passing containers such as std::vector, std::array,
 * std::basic_string<unsigned char> and custom classes as input/output
 * buffers to wally functions. The only requirement is that the container
 * supports data() and size() member functions that return the buffer and
 * its length respectively.
 */
namespace wally {

namespace detail {
#define WALLYB(var) var.data(), var.size()
#define WALLYO(var) var.data() + offset, var.size() - offset

    template <class F, class I> inline int b(F f, I i1) { return f(WALLYB(i1)); }
#define WALLY_FN_B(F)                                                                                                  \
    template <class I> inline int F(I i1) { return detail::b(wally_##F, i1); }

    template <class F, class I> inline int b_6(F f, I i1, size_t* written) { return f(WALLYB(i1), written); }
#define WALLY_FN_B_6(F)                                                                                                \
    template <class I> inline int F(I i1, size_t* written) { return detail::b_6(wally_##F, i1, written); }

    template <class F, class I, class O> inline int b_b(F f, I i1, O out, size_t offset = 0)
    {
        return f(WALLYB(i1), WALLYO(out));
    }
#define WALLY_FN_B_B(F)                                                                                                \
    template <class I, class O> inline int F(I i1, O out, size_t offset = 0)                                           \
    {                                                                                                                  \
        return detail::b_b(wally_##F, i1, out, offset);                                                                \
    }

    template <class F, class I1, class O>
    inline int b3_b6(F f, I1 i1, uint32_t i32, size_t* written, O out, size_t offset = 0)
    {
        return f(WALLYB(i1), i32, WALLYO(out), written);
    }
#define WALLY_FN_B3_B6(F)                                                                                              \
    template <class I1, class O> inline int F(I1 i1, uint32_t i32, size_t* written, O out, size_t offset = 0)          \
    {                                                                                                                  \
        return detail::b3_b6(wally_##F, i1, i32, written, out, offset);                                                \
    }

    template <class F, class I1, class O>
    inline int b33_b6(F f, I1 i1, uint32_t i321, uint32_t i322, size_t* written, O out, size_t offset = 0)
    {
        return f(WALLYB(i1), i321, i322, WALLYO(out), written);
    }
#define WALLY_FN_B33_B6(F)                                                                                             \
    template <class I1, class O>                                                                                       \
    inline int F(I1 i1, uint32_t i321, uint32_t i322, size_t* written, O out, size_t offset = 0)                       \
    {                                                                                                                  \
        return detail::b33_b6(wally_##F, i1, i321, i322, written, out, offset);                                        \
    }

    template <class F, class I, class I2, class O> inline int bb_b(F f, I i1, I2 i2, O out, size_t offset = 0)
    {
        return f(WALLYB(i1), WALLYB(i2), WALLYO(out));
    }
#define WALLY_FN_BB_B(F)                                                                                               \
    template <class I1, class I2, class O> inline int F(I1 i1, I2 i2, O out, size_t offset = 0)                        \
    {                                                                                                                  \
        return detail::bb_b(wally_##F, i1, i2, out, offset);                                                           \
    }

    template <class F, class I1, class I2, class O>
    inline int bb3_b(F f, I1 i1, I2 i2, uint32_t i32, O out, size_t offset = 0)
    {
        return f(WALLYB(i1), WALLYB(i2), i32, WALLYO(out));
    }
#define WALLY_FN_BB3_B(F)                                                                                              \
    template <class I1, class I2, class O> inline int F(I1 i1, I2 i2, uint32_t i32, O out, size_t offset = 0)          \
    {                                                                                                                  \
        return detail::bb3_b(wally_##F, i1, i2, i32, out, offset);                                                     \
    }

    template <class F, class I1, class I2, class O>
    inline int bb33_b(F f, I1 i1, I2 i2, uint32_t i321, uint32_t i322, O out, size_t offset = 0)
    {
        return f(WALLYB(i1), WALLYB(i2), i321, i322, WALLYO(out));
    }
#define WALLY_FN_BB33_B(F)                                                                                             \
    template <class I1, class I2, class O>                                                                             \
    inline int F(I1 i1, I2 i2, uint32_t i321, uint32_t i322, O out, size_t offset = 0)                                 \
    {                                                                                                                  \
        return detail::bb33_b(wally_##F, i1, i2, i321, i322, out, offset);                                             \
    }

    template <class F, class I1, class I2, class I3, class O>
    inline int bbb3_b6(F f, I1 i1, I2 i2, I3 i3, uint32_t i32, size_t* written, O out, size_t offset = 0)
    {
        return f(WALLYB(i1), WALLYB(i2), WALLYB(i3), i32, WALLYO(out), written);
    }
#define WALLY_FN_BBB3_B6(F)                                                                                            \
    template <class I1, class I2, class I3, class O>                                                                   \
    inline int F(I1 i1, I2 i2, I3 i3, uint32_t i32, size_t* written, O out, size_t offset = 0)                         \
    {                                                                                                                  \
        return detail::bbb3_b6(wally_##F, i1, i2, i3, i32, written, out, offset);                                      \
    }

} // namespace detail

WALLY_FN_B(ec_private_key_verify)
WALLY_FN_B(bzero)
WALLY_FN_B(secp_randomize)

WALLY_FN_B_6(scriptpubkey_get_type)

WALLY_FN_B_B(sha256)
WALLY_FN_B_B(sha256d)
WALLY_FN_B_B(sha512)
WALLY_FN_B_B(hash160)
WALLY_FN_B_B(ec_public_key_from_private_key)
WALLY_FN_B_B(ec_public_key_decompress)
WALLY_FN_B_B(ec_sig_normalize)
WALLY_FN_B_B(ec_sig_from_der)

WALLY_FN_B3_B6(format_bitcoin_message)
WALLY_FN_B3_B6(scriptpubkey_p2pkh_from_bytes)
WALLY_FN_B3_B6(scriptpubkey_p2sh_from_bytes)
WALLY_FN_B3_B6(script_push_from_bytes)
WALLY_FN_B3_B6(witness_program_from_bytes)

WALLY_FN_B33_B6(scriptpubkey_multisig_from_bytes)

WALLY_FN_BB_B(hmac_sha256)
WALLY_FN_BB_B(hmac_sha512)

WALLY_FN_BB3_B(aes)
WALLY_FN_BB3_B(ec_sig_verify)

WALLY_FN_BBB3_B6(aes_cbc)
WALLY_FN_BB33_B(pbkdf2_hmac_sha256)
WALLY_FN_BB33_B(pbkdf2_hmac_sha512)

#undef WALLY_FN_B
#undef WALLY_FN_B_6
#undef WALLY_FN_B_B
#undef WALLY_FN_B3_B6
#undef WALLY_FN_B33_B6
#undef WALLY_FN_BB_B
#undef WALLY_FN_BB3_B
#undef WALLY_FN_BBB3_B6
#undef WALLYB
#undef WALLYO

template <class O> inline int tx_to_bytes(struct wally_tx* tx, uint32_t flags, O out, size_t* written)
{
    return wally_tx_to_bytes(tx, flags, out.data(), out.size(), written);
}
} // namespace wally

#endif // GA_SDK_WALLY_WRAPPER_HPP
