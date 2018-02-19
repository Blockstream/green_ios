#include "transaction_utils.hpp"
#include "assertion.hpp"
#include "utils.hpp"
#include "wally.hpp"

namespace ga {
namespace sdk {

    wally_ext_key_ptr derive_key(const wally_ext_key_ptr& key, uint32_t child, bool public_)
    {
        ext_key* p;
        GA_SDK_VERIFY(bip32_key_from_parent_alloc(
            key.get(), child, (public_ ? BIP32_FLAG_KEY_PUBLIC : BIP32_FLAG_KEY_PRIVATE) | BIP32_FLAG_SKIP_HASH, &p));

        return wally_ext_key_ptr{ p };
    }

    wally_ext_key_ptr derive_key(const wally_ext_key_ptr& key, std::pair<uint32_t, uint32_t> path, bool public_)
    {
        return derive_key(derive_key(key, path.first, public_), path.second, public_);
    }

    wally_ext_key_ptr ga_pub_key(const std::string& chain_code, const std::string& pub_key,
        const std::string& gait_path, uint32_t subaccount, uint32_t pointer, bool main_net)
    {
        // FIXME: cache the top level keys
        const auto dcc_bytes = bytes_from_hex(chain_code);
        const auto dpk_bytes = bytes_from_hex(pub_key);

        ext_key* p;
        GA_SDK_VERIFY(
            bip32_key_init_alloc(main_net ? BIP32_VER_MAIN_PUBLIC : BIP32_VER_TEST_PUBLIC, 0, 0, dcc_bytes.data(),
                dcc_bytes.size(), dpk_bytes.data(), dpk_bytes.size(), nullptr, 0, nullptr, 0, nullptr, 0, &p));

        wally_ext_key_ptr server_pub_key{ p };

        const auto gait_path_bytes = bytes_from_hex(gait_path);

        std::vector<uint32_t> path(32 + (subaccount == 0 ? 1 : 2));
        path[0] = subaccount == 0 ? 1 : 3;
        adjacent_transform(gait_path_bytes.begin(), gait_path_bytes.end(), path.begin() + 1,
            [](auto first, auto second) { return uint32_t((first << 8) + second); });

        if (subaccount != 0) {
            path.back() = subaccount;
        }

        ext_key* q;
        GA_SDK_VERIFY(bip32_key_from_parent_path_alloc(
            server_pub_key.get(), path.data(), path.size(), BIP32_FLAG_KEY_PUBLIC | BIP32_FLAG_SKIP_HASH, &q));

        server_pub_key = wally_ext_key_ptr(q);

        return derive_key(server_pub_key, pointer, true);
    }

    std::array<unsigned char, HASH160_LEN + 1> p2sh_address_from_bytes(const std::vector<unsigned char>& script)
    {
        std::array<unsigned char, HASH160_LEN + 1> addr;
        addr[0] = 196;
        GA_SDK_VERIFY(wally::hash160(script, addr, 1));
        return addr;
    }

    std::array<unsigned char, HASH160_LEN + 1> p2wsh_address_from_bytes(const std::vector<unsigned char>& script)
    {
        std::vector<unsigned char> witness;
        size_t written;
        witness.resize(SHA256_LEN + 1);
        GA_SDK_VERIFY(wally::witness_program_from_bytes(script, WALLY_SCRIPT_SHA256, &written, witness));
        GA_SDK_RUNTIME_ASSERT(written == witness.size());
        return p2sh_address_from_bytes(witness);
    }

    std::array<unsigned char, HASH160_LEN + 3> output_script_for_address(const std::string& address)
    {
        std::array<unsigned char, HASH160_LEN + 1 + BASE58_CHECKSUM_LEN> sc;
        size_t written;
        GA_SDK_VERIFY(wally_base58_to_bytes(address.c_str(), 0, sc.data(), sc.size(), &written));

        std::array<unsigned char, HASH160_LEN + 3> script;
        GA_SDK_VERIFY(
            wally_scriptpubkey_p2sh_from_bytes(sc.data() + 1, HASH160_LEN, 0, script.data(), script.size(), &written));

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

    std::array<unsigned char, 3 + SHA256_LEN> witness_script(const std::vector<unsigned char>& script_bytes)
    {
        std::array<unsigned char, 3 + SHA256_LEN> script;
        script[0] = 0x22;
        script[1] = 0x00;
        script[2] = 0x20;
        GA_SDK_VERIFY(wally::sha256(script_bytes, script, 3));
        return script;
    }

    wally_tx_ptr make_tx(uint32_t locktime, const std::vector<wally_tx_input_ptr>& inputs,
        const std::vector<wally_tx_output_ptr>& outputs)
    {
        struct wally_tx* tx;
        GA_SDK_VERIFY(wally_tx_init_alloc(WALLY_TX_VERSION_2, locktime, inputs.size(), outputs.size(), &tx));
        wally_tx_ptr tx_ptr{ tx };

        for (auto&& in : inputs) {
            GA_SDK_VERIFY(wally_tx_add_input(tx, in.get()));
        }
        for (auto&& out : outputs) {
            GA_SDK_VERIFY(wally_tx_add_output(tx, out.get()));
        }

        return tx_ptr;
    }
}
}
