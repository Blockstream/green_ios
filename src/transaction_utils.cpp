#include "transaction_utils.hpp"
#include "assertion.hpp"
#include "utils.hpp"

namespace ga {
namespace sdk {

    wally_ext_key_ptr derive_key(const wally_ext_key_ptr& key, std::uint32_t path, bool public_)
    {
        const ext_key* p = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip32_key_from_parent_alloc(key.get(), path,
                                  (public_ ? BIP32_FLAG_KEY_PUBLIC : BIP32_FLAG_KEY_PRIVATE) | BIP32_FLAG_SKIP_HASH, &p)
            == WALLY_OK);
        return wally_ext_key_ptr(p, &bip32_key_free);
    }

    wally_ext_key_ptr derive_key(
        const wally_ext_key_ptr& key, std::pair<std::uint32_t, std::uint32_t> path, bool public_)
    {
        return derive_key(derive_key(key, path.first, public_), path.second, public_);
    }

    wally_ext_key_ptr ga_pub_key(const std::string& deposit_chain_code, const std::string& deposit_pub_key,
        const std::string& gait_path, int32_t subaccount, uint32_t pointer, bool main_net)
    {
        const auto dcc_bytes = bytes_from_hex(deposit_chain_code.c_str(), deposit_chain_code.size());
        const auto dpk_bytes = bytes_from_hex(deposit_pub_key.c_str(), deposit_pub_key.size());

        const ext_key* p = nullptr;
        GA_SDK_RUNTIME_ASSERT(
            bip32_key_init_alloc(main_net ? BIP32_VER_MAIN_PUBLIC : BIP32_VER_TEST_PUBLIC, 0, 0, dcc_bytes.data(),
                dcc_bytes.size(), dpk_bytes.data(), dpk_bytes.size(), nullptr, 0, nullptr, 0, nullptr, 0, &p)
            == WALLY_OK);
        wally_ext_key_ptr server_pub_key(p, &bip32_key_free);

        const auto gait_path_bytes = bytes_from_hex(gait_path.c_str(), gait_path.size());

        std::vector<uint32_t> path(32 + (subaccount == 0 ? 1 : 2));
        adjacent_transform(gait_path_bytes.begin(), gait_path_bytes.end(), path.begin() + 1,
            [](auto first, auto second) { return uint32_t((first << 8) + second); });

        path[0] = subaccount == 0 ? 1 : 3;
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

    std::array<unsigned char, HASH160_LEN + 1> create_p2sh_script(const std::vector<unsigned char>& script_bytes)
    {
        std::array<unsigned char, HASH160_LEN + 1> hash160{ { 0 } };
        hash160[0] = 196;
        GA_SDK_RUNTIME_ASSERT(
            wally_hash160(script_bytes.data(), script_bytes.size(), hash160.data() + 1, HASH160_LEN) == WALLY_OK);
        return hash160;
    }

    std::array<unsigned char, HASH160_LEN + 1> create_p2wsh_script(const std::vector<unsigned char>& script_bytes)
    {
        std::array<unsigned char, SHA256_LEN> sha256{ { 0 } };
        GA_SDK_RUNTIME_ASSERT(
            wally_sha256(script_bytes.data(), script_bytes.size(), sha256.data(), sha256.size()) == WALLY_OK);

        std::array<unsigned char, 1 + 1 + SHA256_LEN> q{ { 0 } };
        unsigned char* s = q.data();
        size_t written = 0;
        GA_SDK_RUNTIME_ASSERT(script_encode_small_num(0, s, 1, &written) == WALLY_OK);
        s += written;
        GA_SDK_RUNTIME_ASSERT(
            script_encode_data(sha256.data(), sha256.size(), s, q.size() - written, &written) == WALLY_OK);

        std::array<unsigned char, HASH160_LEN + 1> hash160{ { 0 } };
        hash160[0] = 196;
        GA_SDK_RUNTIME_ASSERT(wally_hash160(q.data(), q.size(), hash160.data() + 1, HASH160_LEN) == WALLY_OK);

        return hash160;
    }

    std::array<unsigned char, HASH160_LEN + 3> output_script_for_address(const std::string& address)
    {
        std::array<unsigned char, HASH160_LEN + 1 + BASE58_CHECKSUM_LEN> hash160{ { 0 } };
        size_t written{ 0 };
        GA_SDK_RUNTIME_ASSERT(
            wally_base58_to_bytes(address.data(), 0, hash160.data(), hash160.size(), &written) == WALLY_OK);

        std::array<unsigned char, HASH160_LEN + 3> script{ { 0 } };
        unsigned char* p = script.data();
        GA_SDK_RUNTIME_ASSERT(script_encode_op(OP_HASH160, p, 1, &written) == WALLY_OK);
        p += written;
        GA_SDK_RUNTIME_ASSERT(
            script_encode_data(hash160.data() + 1, HASH160_LEN, p, HASH160_LEN, &written) == WALLY_OK);
        p += written;
        GA_SDK_RUNTIME_ASSERT(script_encode_op(OP_EQUAL, p, 1, &written) == WALLY_OK);

        return script;
    }

    std::array<unsigned char, HASH160_LEN + 3> output_script(
        const std::array<unsigned char, HASH160_LEN + 1>& script_hash)
    {
        size_t written{ 0 };
        std::array<unsigned char, HASH160_LEN + 3> script{ { 0 } };
        unsigned char* p = script.data();
        GA_SDK_RUNTIME_ASSERT(script_encode_op(OP_HASH160, p, 1, &written) == WALLY_OK);
        p += written;
        GA_SDK_RUNTIME_ASSERT(
            script_encode_data(script_hash.data() + 1, HASH160_LEN, p, HASH160_LEN, &written) == WALLY_OK);
        p += written;
        GA_SDK_RUNTIME_ASSERT(script_encode_op(OP_EQUAL, p, 1, &written) == WALLY_OK);

        return script;
    }

    std::vector<unsigned char> output_script(const wally_ext_key_ptr& key, const std::string& deposit_chain_code,
        const std::string& deposit_pub_key, const std::string& gait_path, int32_t subaccount, uint32_t pointer,
        bool main_net)
    {
        const auto server_pub_key
            = ga_pub_key(deposit_chain_code, deposit_pub_key, gait_path, subaccount, pointer, main_net);
        const auto client_pub_key = derive_key(key, { 1, pointer }, true);

        // FIXME: needs code for subaccounts
        //

        std::vector<unsigned char> script;
        script.resize(5 + sizeof(server_pub_key->pub_key) + sizeof(client_pub_key->pub_key));
        unsigned char* p = script.data();

        size_t written;
        GA_SDK_RUNTIME_ASSERT(script_encode_small_num(2, p, 1, &written) == WALLY_OK);
        p += written;
        GA_SDK_RUNTIME_ASSERT(script_encode_data(server_pub_key->pub_key, sizeof server_pub_key->pub_key, p,
                                  sizeof server_pub_key->pub_key + 1, &written)
            == WALLY_OK);
        p += written;
        GA_SDK_RUNTIME_ASSERT(script_encode_data(client_pub_key->pub_key, sizeof client_pub_key->pub_key, p,
                                  sizeof client_pub_key->pub_key + 1, &written)
            == WALLY_OK);
        p += written;
        GA_SDK_RUNTIME_ASSERT(script_encode_small_num(2, p, 1, &written) == WALLY_OK);
        p += written;
        GA_SDK_RUNTIME_ASSERT(script_encode_op(OP_CHECKMULTISIG, p, 1, &written) == WALLY_OK);

        return script;
    }

    std::vector<unsigned char> input_script(
        const std::array<std::array<unsigned char, EC_SIGNATURE_DER_MAX_LEN + 1>, 2>& sigs, size_t sigs_size,
        size_t num_sigs, const std::vector<unsigned char>& output_script)
    {
        std::vector<unsigned char> script;
        script.resize(1 + 1 + output_script.size() + num_sigs * (1 + sigs_size) + 2);

        unsigned char* p = script.data();

        size_t written;
        GA_SDK_RUNTIME_ASSERT(script_encode_small_num(0, p, 1, &written) == WALLY_OK);
        p += written;
        *p = 1;
        p += written;
        GA_SDK_RUNTIME_ASSERT(script_encode_small_num(0, p, 1, &written) == WALLY_OK);
        p += written;
        for (size_t i = 0; i < num_sigs; ++i) {
            GA_SDK_RUNTIME_ASSERT(
                script_encode_data(sigs[i].data(), sigs_size, p, sigs_size + 1, &written) == WALLY_OK);
            p += written;
        }
        GA_SDK_RUNTIME_ASSERT(
            script_encode_data(output_script.data(), output_script.size(), p, output_script.size() + 1, &written)
            == WALLY_OK);
        return script;
    }
}
}
