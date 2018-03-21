#include "transaction_utils.hpp"
#include "assertion.hpp"
#include "utils.hpp"

namespace ga {
namespace sdk {

    wally_ext_key_ptr ga_pub_key(const std::string& chain_code, const std::string& pub_key,
        const std::string& gait_path, uint32_t subaccount, uint32_t pointer, bool main_net)
    {
        // FIXME: cache the top level keys
        const auto dcc_bytes = bytes_from_hex(chain_code);
        const auto dpk_bytes = bytes_from_hex(pub_key);
        const auto gait_path_bytes = bytes_from_hex(gait_path);

        ext_key* p;
        uint32_t version = main_net ? BIP32_VER_MAIN_PUBLIC : BIP32_VER_TEST_PUBLIC;
        const nullbytes nb;
        bip32_key_init_alloc(version, 0, 0, dcc_bytes, dpk_bytes, nb, nb, nb, &p);

        wally_ext_key_ptr server_pub_key{ p };

        std::vector<uint32_t> path(32 + 1);
        path[0] = subaccount ? 3 : 1;
        adjacent_transform(gait_path_bytes.begin(), gait_path_bytes.end(), path.begin() + 1,
            [](auto first, auto second) { return uint32_t((first << 8) + second); });

        if (subaccount) {
            path.push_back(subaccount);
        }
        path.push_back(pointer);

        return derive_key(server_pub_key, path, true);
    }

    std::array<unsigned char, HASH160_LEN + 1> p2sh_address_from_bytes(const secure_vector<unsigned char>& script)
    {
        std::array<unsigned char, HASH160_LEN> hash;
        std::array<unsigned char, HASH160_LEN + 1> addr;
        hash160(script, hash);
        addr[0] = 196;
        std::copy(hash.begin(), hash.end(), addr.begin() + 1);
        return addr;
    }

    std::array<unsigned char, HASH160_LEN + 1> p2wsh_address_from_bytes(const secure_vector<unsigned char>& script)
    {
        secure_vector<unsigned char> witness(SHA256_LEN + 2);
        witness_program_from_bytes(script, WALLY_SCRIPT_SHA256, witness);
        return p2sh_address_from_bytes(witness);
    }

    std::array<unsigned char, HASH160_LEN + 3> output_script_for_address(const std::string& address)
    {
        std::array<unsigned char, HASH160_LEN + 1 + BASE58_CHECKSUM_LEN> sc;
        base58_to_bytes(address, 0, sc);

        std::array<unsigned char, HASH160_LEN + 3> script;
        size_t written;
        GA_SDK_VERIFY(
            wally_scriptpubkey_p2sh_from_bytes(sc.data() + 1, HASH160_LEN, 0, script.data(), script.size(), &written));

        return script;
    }

    secure_vector<unsigned char> output_script(const wally_ext_key_ptr& key, const std::string& deposit_chain_code,
        const std::string& deposit_pub_key, const std::string& gait_path, uint32_t subaccount, uint32_t pointer,
        bool main_net)
    {
        const auto server_pub_key
            = ga_pub_key(deposit_chain_code, deposit_pub_key, gait_path, subaccount, pointer, main_net);
        const auto client_pub_key = derive_key(key, std::array<uint32_t, 2>{ { 1, pointer } }, true);

        // FIXME: needs code for subaccounts
        //

        size_t n_pubkeys = 2, threshold = 2;
        secure_vector<unsigned char> keys;
        keys.reserve(3 * EC_PUBLIC_KEY_LEN);
        keys.insert(keys.end(), server_pub_key->pub_key, server_pub_key->pub_key + EC_PUBLIC_KEY_LEN);
        keys.insert(keys.end(), client_pub_key->pub_key, client_pub_key->pub_key + EC_PUBLIC_KEY_LEN);
        // FIXME: If 2of3, insert 2nd key and increment n_pubkeys here
        secure_vector<unsigned char> script(3 + n_pubkeys * (EC_PUBLIC_KEY_LEN + 1));

        scriptpubkey_multisig_from_bytes(keys, threshold, 0, script);
        return script;
    }

    secure_vector<unsigned char> input_script(
        const std::array<std::array<unsigned char, EC_SIGNATURE_DER_MAX_LEN + 1>, 2>& sigs,
        const std::array<size_t, 2>& sigs_size, size_t num_sigs, const secure_vector<unsigned char>& output_script)
    {
        GA_SDK_RUNTIME_ASSERT(num_sigs > 0 && num_sigs < 3);

        secure_vector<unsigned char> script;
        script.resize(1 + 1 + output_script.size() + (1 + sigs_size[0]) + (num_sigs == 2 ? 1 + sigs_size[1] : 0) + 2);

        unsigned char* p = script.data();

        size_t written;
        *p++ = OP_0;
        *p++ = 1;
        *p++ = OP_0;
        for (size_t i = 0; i < num_sigs; ++i) {
            GA_SDK_VERIFY(wally_script_push_from_bytes(sigs[i].data(), sigs_size[i], 0, p, sigs_size[i] + 1, &written));
            p += written;
        }
        GA_SDK_VERIFY(wally_script_push_from_bytes(
            output_script.data(), output_script.size(), 0, p, output_script.size() + 1, &written));
        return script;
    }

    std::array<unsigned char, 3 + SHA256_LEN> witness_script(const secure_vector<unsigned char>& script)
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
