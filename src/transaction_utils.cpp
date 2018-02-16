#include <wally_script.h>

#include "assertion.hpp"
#include "transaction_utils.hpp"
#include "utils.hpp"

namespace ga {
namespace sdk {

    wally_ext_key_ptr derive_key(const wally_ext_key_ptr& key, uint32_t child, bool public_)
    {
        const ext_key* p = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip32_key_from_parent_alloc(key.get(), child,
                                  (public_ ? BIP32_FLAG_KEY_PUBLIC : BIP32_FLAG_KEY_PRIVATE) | BIP32_FLAG_SKIP_HASH, &p)
            == WALLY_OK);
        return wally_ext_key_ptr(p, &bip32_key_free);
    }

    wally_ext_key_ptr derive_key(
        const wally_ext_key_ptr& key, std::pair<uint32_t, uint32_t> path, bool public_)
    {
        return derive_key(derive_key(key, path.first, public_), path.second, public_);
    }

    wally_ext_key_ptr ga_pub_key(const std::string& chain_code, const std::string& pub_key,
        const std::string& gait_path, uint32_t subaccount, uint32_t pointer, bool main_net)
    {
        // FIXME: cache the top level keys
        const auto dcc_bytes = bytes_from_hex(chain_code.c_str(), chain_code.size());
        const auto dpk_bytes = bytes_from_hex(pub_key.c_str(), pub_key.size());

        const ext_key* p = nullptr;
        GA_SDK_RUNTIME_ASSERT(
            bip32_key_init_alloc(main_net ? BIP32_VER_MAIN_PUBLIC : BIP32_VER_TEST_PUBLIC, 0, 0, dcc_bytes.data(),
                dcc_bytes.size(), dpk_bytes.data(), dpk_bytes.size(), nullptr, 0, nullptr, 0, nullptr, 0, &p)
            == WALLY_OK);
        wally_ext_key_ptr server_pub_key(p, &bip32_key_free);

        const auto gait_path_bytes = bytes_from_hex(gait_path.c_str(), gait_path.size());

        std::vector<uint32_t> path(32 + (subaccount == 0 ? 1 : 2));
        path[0] = subaccount == 0 ? 1 : 3;
        adjacent_transform(gait_path_bytes.begin(), gait_path_bytes.end(), path.begin() + 1,
            [](auto first, auto second) { return uint32_t((first << 8) + second); });

        if (subaccount != 0) {
            path.back() = subaccount;
        }

        const ext_key* q = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip32_key_from_parent_path_alloc(server_pub_key.get(), path.data(), path.size(),
                                  BIP32_FLAG_KEY_PUBLIC | BIP32_FLAG_SKIP_HASH, &q)
            == WALLY_OK);
        server_pub_key = wally_ext_key_ptr(q, &bip32_key_free);

        return derive_key(server_pub_key, pointer, true);
    }

    std::array<unsigned char, HASH160_LEN + 1> p2sh_address_from_bytes(const std::vector<unsigned char>& script_bytes)
    {
        std::array<unsigned char, HASH160_LEN + 1> script{ { 0 } };
        script[0] = 196;
        GA_SDK_RUNTIME_ASSERT(
            wally_hash160(script_bytes.data(), script_bytes.size(), script.data() + 1, HASH160_LEN) == WALLY_OK);
        return script;
    }

    std::array<unsigned char, HASH160_LEN + 1> p2wsh_address_from_bytes(const std::vector<unsigned char>& script_bytes)
    {
        std::array<unsigned char, SHA256_LEN + 1> script{ { 0 } };
        size_t written{ 0 };
        GA_SDK_RUNTIME_ASSERT(wally_witness_program_from_bytes(script_bytes.data(), script_bytes.size(),
                                  WALLY_SCRIPT_SHA256, script.data(), script.size(), &written)
            == WALLY_OK);

        std::array<unsigned char, HASH160_LEN + 1> sc{ { 0 } };
        sc[0] = 196;
        GA_SDK_RUNTIME_ASSERT(wally_hash160(script.data(), script.size(), sc.data() + 1, HASH160_LEN) == WALLY_OK);

        return sc;
    }

    std::array<unsigned char, HASH160_LEN + 3> output_script_for_address(const std::string& address)
    {
        std::array<unsigned char, HASH160_LEN + 1 + BASE58_CHECKSUM_LEN> sc{ { 0 } };
        size_t written{ 0 };
        GA_SDK_RUNTIME_ASSERT(wally_base58_to_bytes(address.c_str(), 0, sc.data(), sc.size(), &written) == WALLY_OK);

        std::array<unsigned char, HASH160_LEN + 3> script{ { 0 } };
        GA_SDK_RUNTIME_ASSERT(
            wally_scriptpubkey_p2sh_from_bytes(sc.data() + 1, HASH160_LEN, 0, script.data(), script.size(), &written)
            == WALLY_OK);

        return script;
    }

    std::vector<unsigned char> output_script(const wally_ext_key_ptr& key, const std::string& deposit_chain_code,
        const std::string& deposit_pub_key, const std::string& gait_path, uint32_t subaccount, uint32_t pointer,
        bool main_net)
    {
        const auto server_pub_key
            = ga_pub_key(deposit_chain_code, deposit_pub_key, gait_path, subaccount, pointer, main_net);
        const auto client_pub_key = derive_key(key, { 1, pointer }, true);

        // FIXME: needs code for subaccounts
        //

        std::vector<unsigned char> keys;
        keys.resize(sizeof server_pub_key->pub_key + sizeof client_pub_key->pub_key);
        std::copy(server_pub_key->pub_key, server_pub_key->pub_key + sizeof server_pub_key->pub_key, keys.begin());
        std::copy(client_pub_key->pub_key, client_pub_key->pub_key + sizeof client_pub_key->pub_key,
            keys.begin() + sizeof server_pub_key->pub_key);

        std::vector<unsigned char> multisig;
        multisig.resize(5 + sizeof server_pub_key->pub_key + sizeof client_pub_key->pub_key);

        size_t written{ 0 };
        GA_SDK_VERIFY(wally_scriptpubkey_multisig_from_bytes(
            keys.data(), keys.size(), 2, 0, multisig.data(), multisig.size(), &written));

        return multisig;
    }

    std::vector<unsigned char> input_script(
        const std::array<std::array<unsigned char, EC_SIGNATURE_DER_MAX_LEN + 1>, 2>& sigs,
        const std::array<size_t, 2>& sigs_size, size_t num_sigs, const std::vector<unsigned char>& output_script)
    {
        GA_SDK_RUNTIME_ASSERT(num_sigs > 0 && num_sigs < 3);

        std::vector<unsigned char> script;
        script.resize(1 + 1 + output_script.size() + (1 + sigs_size[0]) + (num_sigs == 2 ? 1 + sigs_size[1] : 0) + 2);

        unsigned char* p = script.data();

        size_t written{ 0 };
        *p++ = OP_0;
        *p++ = 1;
        *p++ = OP_0;
        for (size_t i = 0; i < num_sigs; ++i) {
            GA_SDK_RUNTIME_ASSERT(
                wally_script_push_from_bytes(sigs[i].data(), sigs_size[i], 0, p, sigs_size[i] + 1, &written)
                == WALLY_OK);
            p += written;
        }
        GA_SDK_RUNTIME_ASSERT(wally_script_push_from_bytes(
                                  output_script.data(), output_script.size(), 0, p, output_script.size() + 1, &written)
            == WALLY_OK);
        return script;
    }

    std::array<unsigned char, 3 + SHA256_LEN> witness_script(const std::vector<unsigned char>& script_bytes)
    {
        std::array<unsigned char, 3 + SHA256_LEN> script{ { 0 } };
        script[0] = 0x22;
        script[1] = 0x00;
        script[2] = 0x20;
        GA_SDK_VERIFY(wally_sha256(script_bytes.data(), script_bytes.size(), script.data() + 3, SHA256_LEN));

        return script;
    }
}
}
