#include "ga_wally.hpp"

namespace ga {
namespace sdk {

    namespace {
        struct string_dtor {
            void operator()(char* p) { wally_free_string(p); }
        };
        inline std::string make_string(char* p) { return std::string(std::unique_ptr<char, string_dtor>(p).get()); }

    } // namespace

    std::array<unsigned char, HASH160_LEN> hash160(byte_span_t data)
    {
        std::array<unsigned char, HASH160_LEN> ret;
        GA_SDK_VERIFY(wally_hash160(data.data(), data.size(), ret.data(), ret.size()));
        return ret;
    }

    std::array<unsigned char, SHA256_LEN> sha256(byte_span_t data)
    {
        std::array<unsigned char, SHA256_LEN> ret;
        GA_SDK_VERIFY(wally_sha256(data.data(), data.size(), ret.data(), ret.size()));
        return ret;
    }

    std::array<unsigned char, SHA256_LEN> sha256d(byte_span_t data)
    {
        std::array<unsigned char, SHA256_LEN> ret;
        GA_SDK_VERIFY(wally_sha256d(data.data(), data.size(), ret.data(), ret.size()));
        return ret;
    }

    std::array<unsigned char, SHA512_LEN> sha512(byte_span_t data)
    {
        std::array<unsigned char, SHA512_LEN> ret;
        GA_SDK_VERIFY(wally_sha512(data.data(), data.size(), ret.data(), ret.size()));
        return ret;
    }

    std::array<unsigned char, HMAC_SHA512_LEN> hmac_sha512(byte_span_t key, byte_span_t data)
    {
        std::array<unsigned char, HMAC_SHA512_LEN> ret;
        GA_SDK_VERIFY(wally_hmac_sha512(key.data(), key.size(), data.data(), data.size(), ret.data(), ret.size()));
        return ret;
    }

    std::array<unsigned char, PBKDF2_HMAC_SHA512_LEN> pbkdf2_hmac_sha512(
        byte_span_t password, byte_span_t salt, uint32_t cost)
    {
        const int32_t flags = 0;
        std::array<unsigned char, PBKDF2_HMAC_SHA512_LEN> ret;
        GA_SDK_VERIFY(wally_pbkdf2_hmac_sha512(
            password.data(), password.size(), salt.data(), salt.size(), flags, cost, ret.data(), ret.size()));
        return ret;
    }

    std::array<unsigned char, PBKDF2_HMAC_SHA256_LEN> pbkdf2_hmac_sha512_256(
        byte_span_t password, byte_span_t salt, uint32_t cost)
    {
        // FIXME: secure_array
        auto tmp = pbkdf2_hmac_sha512(password, salt, cost);
        std::array<unsigned char, PBKDF2_HMAC_SHA256_LEN> out;
        std::copy(std::begin(tmp), std::begin(tmp) + out.size(), std::begin(out));
        wally_bzero(tmp.data(), tmp.size());
        return out;
    }

    //
    // BIP 32
    //
    std::array<unsigned char, BIP32_SERIALIZED_LEN> bip32_key_serialize(const wally_ext_key_ptr& hdkey, uint32_t flags)
    {
        std::array<unsigned char, BIP32_SERIALIZED_LEN> ret;
        GA_SDK_VERIFY(::bip32_key_serialize(hdkey.get(), flags, ret.data(), ret.size()));
        return ret;
    }

    wally_ext_key_ptr bip32_key_unserialize_alloc(byte_span_t data)
    {
        ext_key* p;
        GA_SDK_VERIFY(::bip32_key_unserialize_alloc(data.data(), data.size(), &p));
        return wally_ext_key_ptr{ p };
    }

    ext_key bip32_public_key_from_parent_path(const ext_key& parent, uint32_span_t path)
    {
        const uint32_t flags = BIP32_FLAG_KEY_PUBLIC | BIP32_FLAG_SKIP_HASH;
        ext_key key;
        GA_SDK_VERIFY(::bip32_key_from_parent_path(&parent, path.data(), path.size(), flags, &key));
        return key;
    }

    ext_key bip32_public_key_from_parent(const ext_key& parent, uint32_t pointer)
    {
        return bip32_public_key_from_parent_path(parent, gsl::make_span(&pointer, 1));
    }

    wally_ext_key_ptr bip32_public_key_from_bip32_xpub(const std::string& bip32_xpub)
    {
        return bip32_key_unserialize_alloc(base58check_to_bytes(bip32_xpub));
    }

    wally_ext_key_ptr bip32_key_from_parent_path_alloc(
        const wally_ext_key_ptr& parent, uint32_span_t path, uint32_t flags)
    {
        ext_key* p;
        GA_SDK_VERIFY(::bip32_key_from_parent_path_alloc(parent.get(), path.data(), path.size(), flags, &p));
        return wally_ext_key_ptr{ p };
    }

    wally_ext_key_ptr bip32_key_init_alloc(uint32_t version, uint32_t depth, uint32_t child_num, byte_span_t chain_code,
        byte_span_t pub_key, byte_span_t private_key, byte_span_t hash, byte_span_t parent)
    {
        ext_key* p;
        GA_SDK_VERIFY(::bip32_key_init_alloc(version, depth, child_num, chain_code.data(), chain_code.size(),
            pub_key.data(), pub_key.size(), private_key.data(), private_key.size(), hash.data(), hash.size(),
            parent.data(), parent.size(), &p));
        return wally_ext_key_ptr{ p };
    }

    wally_ext_key_ptr bip32_key_from_seed_alloc(byte_span_t seed, uint32_t version, uint32_t flags)
    {
        ext_key* p;
        GA_SDK_VERIFY(::bip32_key_from_seed_alloc(seed.data(), seed.size(), version, flags, &p));
        return wally_ext_key_ptr{ p };
    }

    //
    // Scripts
    //
    void scriptsig_multisig_from_bytes(
        byte_span_t script, byte_span_t signatures, uint32_span_t sighashes, std::vector<unsigned char>& out)
    {
        const uint32_t flags = 0;
        size_t written;
        GA_SDK_VERIFY(wally_scriptsig_multisig_from_bytes(script.data(), script.size(), signatures.data(),
            signatures.size(), sighashes.data(), sighashes.size(), flags, &out[0], out.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written <= out.size());
        out.resize(written);
    }

    std::vector<unsigned char> scriptsig_p2pkh_from_der(byte_span_t pub_key, byte_span_t sig)
    {
        std::vector<unsigned char> out(2 + pub_key.size() + 2 + sig.size());
        size_t written;
        GA_SDK_VERIFY(wally_scriptsig_p2pkh_from_der(
            pub_key.data(), pub_key.size(), sig.data(), sig.size(), out.data(), out.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written <= out.size());
        out.resize(written);
        return out;
    }

    void scriptpubkey_csv_2of2_then_1_from_bytes(byte_span_t keys, uint32_t csv_blocks, std::vector<unsigned char>& out)
    {
        GA_SDK_RUNTIME_ASSERT(!out.empty());
        const uint32_t flags = 0;
        size_t written;
        GA_SDK_VERIFY(wally_scriptpubkey_csv_2of2_then_1_from_bytes(
            keys.data(), keys.size(), csv_blocks, flags, &out[0], out.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written <= out.size());
        out.resize(written);
    }

    void scriptpubkey_csv_2of3_then_2_from_bytes(byte_span_t keys, uint32_t csv_blocks, std::vector<unsigned char>& out)
    {
        GA_SDK_RUNTIME_ASSERT(!out.empty());
        const uint32_t flags = 0;
        size_t written;
        GA_SDK_VERIFY(wally_scriptpubkey_csv_2of3_then_2_from_bytes(
            keys.data(), keys.size(), csv_blocks, flags, &out[0], out.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written <= out.size());
        out.resize(written);
    }

    void scriptpubkey_multisig_from_bytes(byte_span_t keys, uint32_t threshold, std::vector<unsigned char>& out)
    {
        GA_SDK_RUNTIME_ASSERT(!out.empty());
        const uint32_t flags = 0;
        size_t written;
        GA_SDK_VERIFY(wally_scriptpubkey_multisig_from_bytes(
            keys.data(), keys.size(), threshold, flags, &out[0], out.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written <= out.size());
        out.resize(written);
    }

    std::vector<unsigned char> scriptpubkey_p2pkh_from_hash160(byte_span_t hash)
    {
        GA_SDK_RUNTIME_ASSERT(hash.size() == HASH160_LEN);
        size_t written;
        std::vector<unsigned char> ret(WALLY_SCRIPTPUBKEY_P2PKH_LEN);
        GA_SDK_VERIFY(wally_scriptpubkey_p2pkh_from_bytes(hash.data(), hash.size(), 0, &ret[0], ret.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == WALLY_SCRIPTPUBKEY_P2PKH_LEN);
        return ret;
    }

    std::vector<unsigned char> scriptpubkey_p2sh_from_hash160(byte_span_t hash)
    {
        GA_SDK_RUNTIME_ASSERT(hash.size() == HASH160_LEN);
        size_t written;
        std::vector<unsigned char> ret(WALLY_SCRIPTPUBKEY_P2SH_LEN);
        GA_SDK_VERIFY(wally_scriptpubkey_p2sh_from_bytes(hash.data(), hash.size(), 0, &ret[0], ret.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == WALLY_SCRIPTPUBKEY_P2SH_LEN);
        return ret;
    }

    std::vector<unsigned char> witness_program_from_bytes(byte_span_t script, uint32_t flags)
    {
        size_t written;
        std::vector<unsigned char> ret(WALLY_WITNESSSCRIPT_MAX_LEN);
        GA_SDK_VERIFY(
            wally_witness_program_from_bytes(script.data(), script.size(), flags, &ret[0], ret.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written <= ret.size());
        ret.resize(written);
        return ret;
    }

    std::array<unsigned char, SHA256_LEN> format_bitcoin_message_hash(byte_span_t message)
    {
        const uint32_t flags = BITCOIN_MESSAGE_FLAG_HASH;
        size_t written;
        std::array<unsigned char, SHA256_LEN> ret;
        GA_SDK_VERIFY(
            wally_format_bitcoin_message(message.data(), message.size(), flags, ret.data(), ret.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == ret.size());
        return ret;
    }

    void scrypt(byte_span_t password, byte_span_t salt, uint32_t cost, uint32_t block_size, uint32_t parallelism,
        std::vector<unsigned char>& out)
    {
        GA_SDK_RUNTIME_ASSERT(!out.empty());
        GA_SDK_VERIFY(wally_scrypt(password.data(), password.size(), salt.data(), salt.size(), cost, block_size,
            parallelism, &out[0], out.size()));
    }

    std::string bip39_mnemonic_from_bytes(byte_span_t data)
    {
        char* s;
        GA_SDK_VERIFY(::bip39_mnemonic_from_bytes(nullptr, data.data(), data.size(), &s));
        return make_string(s);
    }

    void bip39_mnemonic_validate(const std::string& mnemonic)
    {
        GA_SDK_VERIFY(::bip39_mnemonic_validate(nullptr, mnemonic.c_str()));
    }

    std::vector<unsigned char> bip39_mnemonic_to_seed(const std::string& mnemonic, const std::string& password)
    {
        GA_SDK_VERIFY(::bip39_mnemonic_validate(nullptr, mnemonic.c_str()));
        size_t written;
        std::vector<unsigned char> ret(BIP39_SEED_LEN_512); // FIXME: secure_array
        GA_SDK_VERIFY(::bip39_mnemonic_to_seed(
            mnemonic.c_str(), password.empty() ? nullptr : password.c_str(), &ret[0], ret.size(), &written));
        return ret;
    }

    std::vector<unsigned char> bip39_mnemonic_to_bytes(const std::string& mnemonic)
    {
        size_t written;
        std::vector<unsigned char> entropy(BIP39_ENTROPY_LEN_288); // FIXME: secure_array
        GA_SDK_VERIFY(::bip39_mnemonic_to_bytes(nullptr, mnemonic.data(), entropy.data(), entropy.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == BIP39_ENTROPY_LEN_256 || written == BIP39_ENTROPY_LEN_288);
        entropy.resize(written);
        return entropy;
    }

    //
    // Strings/Addresses
    //
    std::string hex_from_bytes(byte_span_t data)
    {
        char* ret;
        GA_SDK_VERIFY(wally_hex_from_bytes(data.data(), data.size(), &ret));
        return make_string(ret);
    }

    std::vector<unsigned char> addr_segwit_v0_to_bytes(const std::string& addr, const std::string& family)
    {
        const uint32_t flags = 0;
        size_t written;
        std::vector<unsigned char> ret(WALLY_SCRIPTPUBKEY_P2WSH_LEN);
        GA_SDK_VERIFY(wally_addr_segwit_to_bytes(addr.c_str(), family.c_str(), flags, &ret[0], ret.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == WALLY_SCRIPTPUBKEY_P2WSH_LEN || written == WALLY_SCRIPTPUBKEY_P2WPKH_LEN);
        GA_SDK_RUNTIME_ASSERT(ret[0] == 0); // Must be a segwit v0 script
        ret.resize(written);
        return ret;
    }

    std::string address_from_xpub(unsigned char btc_version, const xpub_t& xpub)
    {
        std::array<unsigned char, HASH160_LEN + 1> addr;
        const auto hash = hash160(xpub.second);
        addr[0] = btc_version;
        std::copy(hash.begin(), hash.end(), addr.begin() + 1);
        return base58check_from_bytes(addr);
    }

    std::string base58check_from_bytes(byte_span_t data)
    {
        char* ret;
        GA_SDK_VERIFY(wally_base58_from_bytes(data.data(), data.size(), BASE58_FLAG_CHECKSUM, &ret));
        return make_string(ret);
    }

    std::vector<unsigned char> base58check_to_bytes(const std::string& base58)
    {
        size_t written;
        GA_SDK_VERIFY(wally_base58_get_length(base58.data(), &written));
        std::vector<unsigned char> ret(written);
        GA_SDK_VERIFY(wally_base58_to_bytes(base58.data(), BASE58_FLAG_CHECKSUM, &ret[0], ret.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written <= ret.size());
        ret.resize(written);
        return ret;
    }

    //
    // Signing/Encryption
    //
    void aes(byte_span_t key, byte_span_t data, uint32_t flags, std::vector<unsigned char>& out)
    {
        GA_SDK_RUNTIME_ASSERT(!out.empty());
        GA_SDK_VERIFY(wally_aes(key.data(), key.size(), data.data(), data.size(), flags, &out[0], out.size()));
    }

    void aes_cbc(byte_span_t key, byte_span_t iv, byte_span_t data, uint32_t flags, std::vector<unsigned char>& out)
    {
        size_t written;
        GA_SDK_RUNTIME_ASSERT(!out.empty());
        GA_SDK_VERIFY(wally_aes_cbc(key.data(), key.size(), iv.data(), iv.size(), data.data(), data.size(), flags,
            &out[0], out.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written <= out.size());
        out.resize(written);
    }

    ecdsa_sig_t ec_sig_from_bytes(byte_span_t private_key, byte_span_t hash, uint32_t flags)
    {
        ecdsa_sig_t ret;
        GA_SDK_VERIFY(wally_ec_sig_from_bytes(
            private_key.data(), private_key.size(), hash.data(), hash.size(), flags, ret.data(), ret.size()));
        return ret;
    }

    std::vector<unsigned char> ec_sig_to_der(byte_span_t sig, bool sighash)
    {
        std::vector<unsigned char> der(EC_SIGNATURE_DER_MAX_LEN + (sighash ? 1 : 0));
        size_t written;
        GA_SDK_VERIFY(wally_ec_sig_to_der(sig.data(), sig.size(), der.data(), der.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written <= der.size());
        der.resize(written);
        if (sighash) {
            der.push_back(WALLY_SIGHASH_ALL);
        }
        return der;
    }

    std::vector<unsigned char> ec_public_key_from_private_key(byte_span_t private_key)
    {
        std::vector<unsigned char> ret(EC_PUBLIC_KEY_LEN);
        GA_SDK_VERIFY(
            wally_ec_public_key_from_private_key(private_key.data(), private_key.size(), ret.data(), ret.size()));
        return ret;
    }

    std::vector<unsigned char> ec_public_key_decompress(byte_span_t public_key)
    {
        std::vector<unsigned char> ret(EC_PUBLIC_KEY_UNCOMPRESSED_LEN);
        GA_SDK_VERIFY(wally_ec_public_key_decompress(public_key.data(), public_key.size(), ret.data(), ret.size()));
        return ret;
    }

    // FIXME: move to wally?
    std::vector<unsigned char> wif_to_private_key_bytes(
        const std::string& wif_priv_key, unsigned char version, bool& compressed)
    {
        const std::vector<unsigned char> priv_key_bytes = base58check_to_bytes(wif_priv_key);
        GA_SDK_RUNTIME_ASSERT(priv_key_bytes.size() == 33 || priv_key_bytes.size() == 34);
        GA_SDK_RUNTIME_ASSERT(priv_key_bytes[0] == version);
        compressed = priv_key_bytes.size() == 34;
        if (compressed) {
            GA_SDK_RUNTIME_ASSERT(priv_key_bytes[33] == 0x01);
        }
        return priv_key_bytes;
    }

    //
    // Transactions
    //
    size_t tx_get_length(const wally_tx_ptr& tx, uint32_t flags)
    {
        size_t written;
        GA_SDK_VERIFY(wally_tx_get_length(tx.get(), flags, &written));
        return written;
    }

    std::vector<unsigned char> tx_to_bytes(const wally_tx_ptr& tx, uint32_t flags)
    {
        std::vector<unsigned char> buff(tx_get_length(tx, flags));
        size_t written;
        GA_SDK_VERIFY(wally_tx_to_bytes(tx.get(), flags, buff.data(), buff.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == buff.size());
        return buff;
    }

    void tx_add_raw_output(const wally_tx_ptr& tx, uint64_t satoshi, byte_span_t script)
    {
        const uint32_t flags = 0;
        GA_SDK_VERIFY(wally_tx_add_raw_output(tx.get(), satoshi, script.data(), script.size(), flags));
    }

    std::array<unsigned char, SHA256_LEN> tx_get_btc_signature_hash(
        const wally_tx_ptr& tx, size_t index, byte_span_t script, uint64_t satoshi, uint32_t sighash, uint32_t flags)
    {
        std::array<unsigned char, SHA256_LEN> tx_hash;
        GA_SDK_VERIFY(wally_tx_get_btc_signature_hash(
            tx.get(), index, script.data(), script.size(), satoshi, sighash, flags, tx_hash.data(), tx_hash.size()));
        return tx_hash;
    }

    wally_tx_ptr tx_init(
        uint32_t locktime, size_t inputs_allocation_len, size_t outputs_allocation_len, uint32_t version)
    {
        struct wally_tx* p;
        GA_SDK_VERIFY(wally_tx_init_alloc(version, locktime, inputs_allocation_len, outputs_allocation_len, &p));
        return wally_tx_ptr(p);
    }

    wally_tx_ptr tx_from_hex(const std::string& tx_hex, uint32_t flags)
    {
        struct wally_tx* p;
        GA_SDK_VERIFY(wally_tx_from_hex(tx_hex.c_str(), flags, &p));
        return wally_tx_ptr(p);
    }

    void tx_add_input(const wally_tx_ptr& tx, const wally_tx_input_ptr& input)
    {
        GA_SDK_VERIFY(wally_tx_add_input(tx.get(), input.get()));
    }

    void tx_add_output(const wally_tx_ptr& tx, const wally_tx_output_ptr& output)
    {
        GA_SDK_VERIFY(wally_tx_add_output(tx.get(), output.get()));
    }

    void tx_add_raw_input(const wally_tx_ptr& tx, byte_span_t txhash, uint32_t index, uint32_t sequence,
        byte_span_t script, const wally_tx_witness_stack_ptr& witness)
    {
        const uint32_t flags = 0;
        GA_SDK_VERIFY(wally_tx_add_raw_input(tx.get(), txhash.data(), txhash.size(), index, sequence, script.data(),
            script.size(), witness.get(), flags));
    }

    size_t tx_get_vsize(const wally_tx_ptr& tx)
    {
        size_t written;
        GA_SDK_VERIFY(wally_tx_get_vsize(tx.get(), &written));
        return written;
    }

    size_t tx_get_weight(const wally_tx_ptr& tx)
    {
        size_t written;
        GA_SDK_VERIFY(wally_tx_get_weight(tx.get(), &written));
        return written;
    }

    void tx_set_input_script(const wally_tx_ptr& tx, size_t index, byte_span_t script)
    {
        GA_SDK_VERIFY(wally_tx_set_input_script(tx.get(), index, script.data(), script.size()));
    }

    void tx_set_input_witness(const wally_tx_ptr& tx, size_t index, const wally_tx_witness_stack_ptr& witness)
    {
        GA_SDK_VERIFY(wally_tx_set_input_witness(tx.get(), index, witness.get()));
    }

    size_t tx_vsize_from_weight(size_t weight)
    {
        size_t written;
        GA_SDK_VERIFY(wally_tx_vsize_from_weight(weight, &written));
        return written;
    }

    wally_tx_witness_stack_ptr tx_witness_stack_init(size_t allocation_len)
    {
        struct wally_tx_witness_stack* p;
        GA_SDK_VERIFY(wally_tx_witness_stack_init_alloc(allocation_len, &p));
        return wally_tx_witness_stack_ptr(p);
    }

    void tx_witness_stack_add(const wally_tx_witness_stack_ptr& stack, byte_span_t witness)
    {
        GA_SDK_VERIFY(wally_tx_witness_stack_add(stack.get(), witness.data(), witness.size()));
    }

    void tx_witness_stack_add_dummy(const wally_tx_witness_stack_ptr& stack, uint32_t flags)
    {
        GA_SDK_VERIFY(wally_tx_witness_stack_add_dummy(stack.get(), flags));
    }

    xpub_t make_xpub(const std::string& chain_code_hex, const std::string& pub_key_hex)
    {
        size_t written;
        xpub_t xpub;
        GA_SDK_VERIFY(wally_hex_to_bytes(chain_code_hex.c_str(), xpub.first.data(), xpub.first.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == xpub.first.size());
        GA_SDK_VERIFY(wally_hex_to_bytes(pub_key_hex.c_str(), xpub.second.data(), xpub.second.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == xpub.second.size());
        return xpub;
    }

    xpub_t make_xpub(const ext_key* hdkey)
    {
        xpub_t xpub;
        std::copy(std::begin(hdkey->chain_code), std::end(hdkey->chain_code), std::begin(xpub.first));
        std::copy(std::begin(hdkey->pub_key), std::end(hdkey->pub_key), std::begin(xpub.second));
        return xpub;
    }

    xpub_t make_xpub(const std::string& bip32_xpub)
    {
        return make_xpub(bip32_public_key_from_bip32_xpub(bip32_xpub).get());
    }
} /* namespace sdk */
} /* namespace ga */
