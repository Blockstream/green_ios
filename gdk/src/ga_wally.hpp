#ifndef GA_SDK_CORE_WALLY_HPP
#define GA_SDK_CORE_WALLY_HPP
#pragma once

#include <array>
#include <gsl/span>
#include <memory>
#include <string>
#include <vector>
#include <wally_address.h>
#include <wally_bip32.h>
#include <wally_bip38.h>
#include <wally_bip39.h>
#include <wally_core.h>
#include <wally_crypto.h>
#include <wally_script.h>
#include <wally_transaction.h>

#include "assertion.hpp"

namespace std {
template <> struct default_delete<struct ext_key> {
    void operator()(struct ext_key* ptr) const { ::bip32_key_free(ptr); }
};

template <> struct default_delete<struct wally_tx_input> {
    void operator()(struct wally_tx_input* ptr) const { wally_tx_input_free(ptr); }
};

template <> struct default_delete<struct wally_tx_witness_stack> {
    void operator()(struct wally_tx_witness_stack* ptr) const { wally_tx_witness_stack_free(ptr); }
};

template <> struct default_delete<struct wally_tx_output> {
    void operator()(struct wally_tx_output* ptr) const { wally_tx_output_free(ptr); }
};

template <> struct default_delete<struct wally_tx> {
    void operator()(struct wally_tx* ptr) const { wally_tx_free(ptr); }
};
} // namespace std

namespace ga {
namespace sdk {
    using wally_ext_key_ptr = std::unique_ptr<struct ext_key>;
    using wally_tx_input_ptr = std::unique_ptr<struct wally_tx_input>;
    using wally_tx_witness_stack_ptr = std::unique_ptr<struct wally_tx_witness_stack>;
    using wally_tx_output_ptr = std::unique_ptr<struct wally_tx_output>;
    using wally_tx_ptr = std::unique_ptr<struct wally_tx>;

    using byte_span_t = gsl::span<const unsigned char>;
    using uint32_span_t = gsl::span<const uint32_t>;

    using ecdsa_sig_t = std::array<unsigned char, EC_SIGNATURE_LEN>;
    using chain_code_t = std::array<unsigned char, 32>;
    using pub_key_t = std::array<unsigned char, EC_PUBLIC_KEY_LEN>;
    using xpub_t = std::pair<chain_code_t, pub_key_t>;

#ifdef __GNUC__
#define GA_USE_RESULT __attribute__((warn_unused_result))
#else
#define GA_USE_RESULT
#endif

    //
    // Hashing/HMAC
    //
    std::array<unsigned char, HASH160_LEN> hash160(byte_span_t data);

    std::array<unsigned char, SHA256_LEN> sha256(byte_span_t data);

    std::array<unsigned char, SHA256_LEN> sha256d(byte_span_t data);

    std::array<unsigned char, SHA512_LEN> sha512(byte_span_t data);

    std::array<unsigned char, HMAC_SHA512_LEN> hmac_sha512(byte_span_t key, byte_span_t data);

    std::array<unsigned char, PBKDF2_HMAC_SHA512_LEN> pbkdf2_hmac_sha512(
        byte_span_t password, byte_span_t salt, uint32_t cost = 2048);

    // PBKDF2-HMAC-SHA512, truncated to 256 bits
    std::array<unsigned char, PBKDF2_HMAC_SHA256_LEN> pbkdf2_hmac_sha512_256(
        byte_span_t password, byte_span_t salt, uint32_t cost = 2048);

    //
    // BIP 32
    //
    std::array<unsigned char, BIP32_SERIALIZED_LEN> bip32_key_serialize(const wally_ext_key_ptr& hdkey, uint32_t flags);

    wally_ext_key_ptr bip32_key_unserialize_alloc(byte_span_t data);

    ext_key bip32_public_key_from_parent_path(const ext_key& parent, uint32_span_t path);

    ext_key bip32_public_key_from_parent(const ext_key& parent, uint32_t pointer);

    wally_ext_key_ptr bip32_public_key_from_bip32_xpub(const std::string& bip32_xpub);

    wally_ext_key_ptr bip32_key_from_parent_path_alloc(
        const wally_ext_key_ptr& parent, uint32_span_t path, uint32_t flags);

    wally_ext_key_ptr bip32_key_init_alloc(uint32_t version, uint32_t depth, uint32_t child_num, byte_span_t chain_code,
        byte_span_t pub_key, byte_span_t private_key = byte_span_t(), byte_span_t hash = byte_span_t(),
        byte_span_t parent = byte_span_t());

    wally_ext_key_ptr bip32_key_from_seed_alloc(
        byte_span_t seed, uint32_t version, uint32_t flags = BIP32_FLAG_SKIP_HASH);

    //
    // Scripts
    //
    void scriptsig_multisig_from_bytes(
        byte_span_t script, byte_span_t signatures, uint32_span_t sighashes, std::vector<unsigned char>& out);

    std::vector<unsigned char> scriptsig_p2pkh_from_der(byte_span_t pub_key, byte_span_t sig);

    void scriptpubkey_csv_2of2_then_1_from_bytes(
        byte_span_t keys, uint32_t csv_blocks, std::vector<unsigned char>& out);

    void scriptpubkey_csv_2of3_then_2_from_bytes(
        byte_span_t keys, uint32_t csv_blocks, std::vector<unsigned char>& out);

    void scriptpubkey_multisig_from_bytes(byte_span_t keys, uint32_t threshold, std::vector<unsigned char>& out);

    std::vector<unsigned char> scriptpubkey_p2pkh_from_hash160(byte_span_t hash);

    std::vector<unsigned char> scriptpubkey_p2sh_from_hash160(byte_span_t hash);

    std::vector<unsigned char> witness_program_from_bytes(byte_span_t script, uint32_t flags);

    std::array<unsigned char, SHA256_LEN> format_bitcoin_message_hash(byte_span_t message);

    void scrypt(byte_span_t password, byte_span_t salt, uint32_t cost, uint32_t block_size, uint32_t parallelism,
        std::vector<unsigned char>& out);

    std::string bip39_mnemonic_from_bytes(byte_span_t data);

    void bip39_mnemonic_validate(const std::string& mnemonic);

    std::vector<unsigned char> bip39_mnemonic_to_seed(
        const std::string& mnemonic, const std::string& password = std::string());

    std::vector<unsigned char> bip39_mnemonic_to_bytes(const std::string& mnemonic);

    //
    // Strings/Addresses
    //
    std::string hex_from_bytes(byte_span_t data);

    std::vector<unsigned char> addr_segwit_v0_to_bytes(const std::string& addr, const std::string& family);

    std::string address_from_xpub(unsigned char btc_version, const xpub_t& xpub);

    std::string base58check_from_bytes(byte_span_t data);

    std::vector<unsigned char> base58check_to_bytes(const std::string& base58);

    //
    // Signing/Encryption
    //
    void aes(byte_span_t key, byte_span_t data, uint32_t flags, std::vector<unsigned char>& out);

    void aes_cbc(byte_span_t key, byte_span_t iv, byte_span_t data, uint32_t flags, std::vector<unsigned char>& out);

    ecdsa_sig_t ec_sig_from_bytes(
        byte_span_t private_key, byte_span_t hash, uint32_t flags = EC_FLAG_ECDSA | EC_FLAG_GRIND_R);

    std::vector<unsigned char> ec_sig_to_der(byte_span_t sig, bool sighash = false);

    std::vector<unsigned char> ec_public_key_from_private_key(byte_span_t private_key);

    std::vector<unsigned char> ec_public_key_decompress(byte_span_t public_key);

    std::vector<unsigned char> wif_to_private_key_bytes(
        const std::string& wif_priv_key, unsigned char version, bool& compressed);

    //
    // Transactions
    //
    GA_USE_RESULT size_t tx_get_length(const wally_tx_ptr& tx, uint32_t flags = WALLY_TX_FLAG_USE_WITNESS);

    std::vector<unsigned char> tx_to_bytes(const wally_tx_ptr& tx, uint32_t flags = WALLY_TX_FLAG_USE_WITNESS);

    void tx_add_raw_output(const wally_tx_ptr& tx, uint64_t satoshi, byte_span_t script);

    std::array<unsigned char, SHA256_LEN> tx_get_btc_signature_hash(const wally_tx_ptr& tx, size_t index,
        byte_span_t script, uint64_t satoshi, uint32_t sighash = WALLY_SIGHASH_ALL,
        uint32_t flags = WALLY_TX_FLAG_USE_WITNESS);

    wally_tx_ptr tx_init(uint32_t locktime, size_t inputs_allocation_len, size_t outputs_allocation_len = 2,
        uint32_t version = WALLY_TX_VERSION_2);

    wally_tx_ptr tx_from_hex(const std::string& tx_hex, uint32_t flags = WALLY_TX_FLAG_USE_WITNESS);

    void tx_add_input(const wally_tx_ptr& tx, const wally_tx_input_ptr& input);

    void tx_add_output(const wally_tx_ptr& tx, const wally_tx_output_ptr& output);

    void tx_add_raw_input(const wally_tx_ptr& tx, byte_span_t txhash, uint32_t index, uint32_t sequence,
        byte_span_t script, const wally_tx_witness_stack_ptr& witness = wally_tx_witness_stack_ptr());

    GA_USE_RESULT size_t tx_get_vsize(const wally_tx_ptr& tx);

    GA_USE_RESULT size_t tx_get_weight(const wally_tx_ptr& tx);

    void tx_set_input_script(const wally_tx_ptr& tx, size_t index, byte_span_t script);

    void tx_set_input_witness(const wally_tx_ptr& tx, size_t index, const wally_tx_witness_stack_ptr& witness);

    GA_USE_RESULT size_t tx_vsize_from_weight(size_t weight);

    wally_tx_witness_stack_ptr tx_witness_stack_init(size_t allocation_len);

    void tx_witness_stack_add(const wally_tx_witness_stack_ptr& stack, byte_span_t witness);

    void tx_witness_stack_add_dummy(const wally_tx_witness_stack_ptr& stack, uint32_t flags);

    xpub_t make_xpub(const ext_key* hdkey);
    xpub_t make_xpub(const std::string& chain_code_hex, const std::string& pub_key_hex);
    xpub_t make_xpub(const std::string& bip32_xpub);

    constexpr uint32_t harden(uint32_t pointer) { return pointer | 0x80000000; }
    constexpr uint32_t unharden(uint32_t pointer) { return pointer & 0x7fffffff; }

#undef GA_USE_RESULT

} /* namespace sdk */
} /* namespace ga */

#endif /* GA_SDK_CORE_WALLY_HPP */
