#include "transaction_utils.hpp"
#include "assertion.hpp"
#include "utils.hpp"

namespace ga {
namespace sdk {
    static const std::array<unsigned char, EC_SIGNATURE_LEN> DUMMY_GA_SIG
        = { { 0xff, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
            0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0xff, 0x7f, 0x7f,
            0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
            0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f } };
    static const std::array<unsigned char, 75> DUMMY_GA_SIG_DER_PUSH = { { 0x00, 0x49, 0x30, 0x46, 0x02, 0x21, 0x00,
        0xff, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
        0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x02, 0x21, 0x00, 0xff,
        0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
        0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x01 } };
    static const std::array<unsigned char, 3> OP_0_PREFIX = { { 0x00, 0x01, 0x00 } };

    wally_ext_key_ptr ga_pub_key(const std::string& chain_code, const std::string& pub_key,
        const std::string& gait_path, uint32_t subaccount, uint32_t pointer, bool main_net)
    {
        // FIXME: cache the top level keys
        const auto dcc_bytes = bytes_from_hex(chain_code);
        const auto dpk_bytes = bytes_from_hex(pub_key);
        const auto gait_path_bytes = bytes_from_hex(gait_path);

        ext_key* p;
        uint32_t version = main_net ? BIP32_VER_MAIN_PUBLIC : BIP32_VER_TEST_PUBLIC;
        bip32_key_init_alloc(version, 0, 0, dcc_bytes, dpk_bytes, nullbytes(), nullbytes(), nullbytes(), &p);

        wally_ext_key_ptr server_pub_key{ p };

        std::vector<uint32_t> path(32 + 1);
        path[0] = subaccount != 0 ? 3 : 1;
        adjacent_transform(gait_path_bytes.begin(), gait_path_bytes.end(), path.begin() + 1,
            [](auto first, auto second) { return uint32_t((first << 8) + second); });

        if (subaccount != 0) {
            path.push_back(subaccount);
        }
        path.push_back(pointer);

        return derive_key(server_pub_key, path, true);
    }

    std::array<unsigned char, HASH160_LEN + 1> p2sh_address_from_bytes(const std::vector<unsigned char>& script)
    {
        std::array<unsigned char, HASH160_LEN> hash;
        std::array<unsigned char, HASH160_LEN + 1> addr;
        hash160(script, hash);
        addr[0] = 196;
        std::copy(hash.begin(), hash.end(), addr.begin() + 1);
        return addr;
    }

    std::array<unsigned char, HASH160_LEN + 1> p2wsh_address_from_bytes(const std::vector<unsigned char>& script)
    {
        std::vector<unsigned char> witness(SHA256_LEN + 2);
        witness_program_from_bytes(script, WALLY_SCRIPT_SHA256, witness);
        return p2sh_address_from_bytes(witness);
    }

    std::array<unsigned char, WALLY_SCRIPTPUBKEY_P2SH_LEN> output_script_for_address(const std::string& address)
    {
        std::array<unsigned char, HASH160_LEN + 1 + BASE58_CHECKSUM_LEN> sc;
        base58_to_bytes(address, 0, sc);

        std::array<unsigned char, WALLY_SCRIPTPUBKEY_P2SH_LEN> script;
        scriptpubkey_p2sh_from_bytes(make_bytes_view(sc.data() + 1, HASH160_LEN), 0, script);
        return script;
    }

    std::vector<unsigned char> output_script(const wally_ext_key_ptr& key, const std::string& deposit_chain_code,
        const std::string& deposit_pub_key, const std::string& gait_path, uint32_t subaccount, uint32_t pointer,
        bool main_net)
    {
        const auto server_pub_key
            = ga_pub_key(deposit_chain_code, deposit_pub_key, gait_path, subaccount, pointer, main_net);
        const auto client_pub_key = derive_key(key, std::array<uint32_t, 2>{ { 1, pointer } }, true);

        // FIXME: needs code for subaccounts
        //

        size_t n_pubkeys = 2, threshold = 2;
        std::vector<unsigned char> keys;
        keys.reserve(3 * EC_PUBLIC_KEY_LEN);
        const auto spub_key = static_cast<unsigned char*>(server_pub_key->pub_key);
        const auto cpub_key = static_cast<unsigned char*>(client_pub_key->pub_key);
        keys.insert(keys.end(), spub_key, spub_key + EC_PUBLIC_KEY_LEN);
        keys.insert(keys.end(), cpub_key, cpub_key + EC_PUBLIC_KEY_LEN);
        // FIXME: If 2of3, insert 2nd key and increment n_pubkeys here
        std::vector<unsigned char> script(3 + n_pubkeys * (EC_PUBLIC_KEY_LEN + 1));

        scriptpubkey_multisig_from_bytes(keys, threshold, 0, script);
        return script;
    }

    std::vector<unsigned char> input_script(const std::vector<unsigned char>& prevout_script,
        const std::array<unsigned char, EC_SIGNATURE_LEN>& user_sig,
        const std::array<unsigned char, EC_SIGNATURE_LEN>& ga_sig)
    {
        const std::array<uint32_t, 2> sighashes = { { WALLY_SIGHASH_ALL, WALLY_SIGHASH_ALL } };
        std::array<unsigned char, EC_SIGNATURE_LEN * 2> sigs;
        init_container(sigs, ga_sig, user_sig);
        std::vector<unsigned char> script(1 + (EC_SIGNATURE_DER_MAX_LEN + 2) * 2 + 3 + prevout_script.size());
        size_t written;
        scriptsig_multisig_from_bytes(prevout_script, sigs, sighashes, 0, script, &written);
        GA_SDK_RUNTIME_ASSERT(written <= script.size());
        script.resize(written);
        return script;
    }

    std::vector<unsigned char> input_script(
        const std::vector<unsigned char>& prevout_script, const std::array<unsigned char, EC_SIGNATURE_LEN>& user_sig)
    {
        std::vector<unsigned char> full_script = input_script(prevout_script, user_sig, DUMMY_GA_SIG);
        // Replace the dummy sig with PUSH(0)
        GA_SDK_RUNTIME_ASSERT(std::search(full_script.begin(), full_script.end(), DUMMY_GA_SIG_DER_PUSH.begin(),
                                  DUMMY_GA_SIG_DER_PUSH.end())
            == full_script.begin());
        auto suffix = make_bytes_view(
            full_script.data() + DUMMY_GA_SIG_DER_PUSH.size(), full_script.size() - DUMMY_GA_SIG_DER_PUSH.size());

        std::vector<unsigned char> script(OP_0_PREFIX.size() + suffix.size());
        init_container(script, OP_0_PREFIX, suffix);
        return script;
    }

    std::vector<unsigned char> dummy_input_script(const std::vector<unsigned char>& prevout_script)
    {
        return input_script(prevout_script, DUMMY_GA_SIG, DUMMY_GA_SIG);
    }

    std::array<unsigned char, 3 + SHA256_LEN> witness_script(const std::vector<unsigned char>& script)
    {
        std::array<unsigned char, 3 + SHA256_LEN> witness;
        witness_program_from_bytes(script, WALLY_SCRIPT_SHA256 | WALLY_SCRIPT_AS_PUSH, witness);
        return witness;
    }

    std::vector<unsigned char> tx_to_bytes(const wally_tx_ptr& tx)
    {
        size_t length;
        tx_get_length(tx, WALLY_TX_FLAG_USE_WITNESS, &length);
        std::vector<unsigned char> bytes(length);
        tx_to_bytes(tx, WALLY_TX_FLAG_USE_WITNESS, bytes);
        return bytes;
    }
}
}
