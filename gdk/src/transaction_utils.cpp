#include <gsl/span>

#include "boost_wrapper.hpp"

#include "include/assertion.hpp"
#include "include/network_parameters.hpp"
#include "memory.hpp"
#include "transaction_utils.hpp"
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

    namespace {
        static wally_ext_key_ptr ga_pub_key(
            const network_parameters& net_params, const std::string& gait_path, uint32_t subaccount, uint32_t pointer)
        {
            using bytes = std::vector<unsigned char>;

            GA_SDK_RUNTIME_ASSERT(!net_params.chain_code().empty());
            GA_SDK_RUNTIME_ASSERT(!net_params.pub_key().empty());

            // FIXME: cache the top level keys
            const auto dcc_bytes = bytes_from_hex(net_params.chain_code());
            const auto dpk_bytes = bytes_from_hex(net_params.pub_key());
            const auto gait_path_bytes = bytes_from_hex(gait_path);

            ext_key* p;
            uint32_t version = net_params.main_net() ? BIP32_VER_MAIN_PUBLIC : BIP32_VER_TEST_PUBLIC;
            bip32_key_init_alloc(version, 0, 0, dcc_bytes, dpk_bytes, bytes{}, bytes{}, bytes{}, &p);

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
    } // namespace

    std::array<unsigned char, HASH160_LEN + 1> p2sh_address_from_bytes(
        const network_parameters& net_params, const std::vector<unsigned char>& script)
    {
        std::array<unsigned char, HASH160_LEN> hash;
        std::array<unsigned char, HASH160_LEN + 1> addr;
        hash160(script, hash);
        addr[0] = net_params.btc_p2sh_version();
        std::copy(hash.begin(), hash.end(), addr.begin() + 1);
        return addr;
    }

    std::array<unsigned char, HASH160_LEN + 1> p2sh_p2wsh_address_from_bytes(
        const network_parameters& net_params, const std::vector<unsigned char>& script)
    {
        std::vector<unsigned char> witness(SHA256_LEN + 2);
        GA_SDK_RUNTIME_ASSERT(witness_program_from_bytes(script, WALLY_SCRIPT_SHA256, witness) == witness.size());
        return p2sh_address_from_bytes(net_params, witness);
    }

    std::vector<unsigned char> output_script_for_address(
        const network_parameters& net_params, const std::string& address)
    {
        std::vector<unsigned char> ret;
        if (boost::starts_with(address, net_params.bech32_prefix())) {
            std::array<unsigned char, WALLY_SCRIPTPUBKEY_P2WSH_LEN> script;
            size_t written = addr_segwit_to_bytes(address, net_params.bech32_prefix(), 0, script);

            GA_SDK_RUNTIME_ASSERT(written == WALLY_SCRIPTPUBKEY_P2WSH_LEN || written == WALLY_SCRIPTPUBKEY_P2WPKH_LEN);
            GA_SDK_RUNTIME_ASSERT(script[0] == 0); // Must be a segwit v0 script
            ret.assign(std::begin(script), std::begin(script) + written);
        } else {
            std::array<unsigned char, 1 + HASH160_LEN + BASE58_CHECKSUM_LEN> sc;
            const size_t written = base58_to_bytes(address, BASE58_FLAG_CHECKSUM, sc);
            GA_SDK_RUNTIME_ASSERT(written == 1 + HASH160_LEN);
            const auto script_hash = gsl::make_span(sc.data() + 1, written - 1);

            if (sc.front() == net_params.btc_p2sh_version()) {
                std::array<unsigned char, WALLY_SCRIPTPUBKEY_P2SH_LEN> script;
                GA_SDK_RUNTIME_ASSERT(scriptpubkey_p2sh_from_bytes(script_hash, 0, script) == script.size());
                ret.assign(std::begin(script), std::end(script));
            } else if (sc.front() == net_params.btc_version()) {
                std::array<unsigned char, WALLY_SCRIPTPUBKEY_P2PKH_LEN> script;
                GA_SDK_RUNTIME_ASSERT(scriptpubkey_p2pkh_from_bytes(script_hash, 0, script) == script.size());
                ret.assign(std::begin(script), std::end(script));
            } else {
                GA_SDK_RUNTIME_ASSERT(false); // Unknown address version
            }
        }
        return ret;
    }

    std::vector<unsigned char> output_script(const network_parameters& net_params, const wally_ext_key_ptr& key,
        const wally_ext_key_ptr& backup_key, const std::string& gait_path, script_type type, uint32_t subtype,
        uint32_t subaccount, uint32_t pointer)
    {
        const bool is_2of3 = !!backup_key;
        const auto server_child_key = ga_pub_key(net_params, gait_path, subaccount, pointer);
        const auto child_path = std::array<uint32_t, 2>{ { 1, pointer } };
        const auto client_child_key = derive_key(key, child_path, true);

        size_t n_pubkeys = 2, threshold = 2;
        std::vector<unsigned char> keys;
        keys.reserve(3 * EC_PUBLIC_KEY_LEN);
        const auto spub_key = static_cast<unsigned char*>(server_child_key->pub_key);
        const auto cpub_key = static_cast<unsigned char*>(client_child_key->pub_key);
        keys.insert(keys.end(), spub_key, spub_key + EC_PUBLIC_KEY_LEN);
        keys.insert(keys.end(), cpub_key, cpub_key + EC_PUBLIC_KEY_LEN);
        if (is_2of3) {
            const auto backup_child_key = derive_key(backup_key, child_path, true);
            const auto bpub_key = static_cast<unsigned char*>(backup_child_key->pub_key);
            keys.insert(keys.end(), bpub_key, bpub_key + EC_PUBLIC_KEY_LEN);
            ++n_pubkeys;
        }

        const size_t max_script_len = 13 + n_pubkeys * (EC_PUBLIC_KEY_LEN + 1) + 4;
        std::vector<unsigned char> script(max_script_len);
        size_t written;

        if (type == script_type::p2sh_p2wsh_csv_fortified_out && is_2of3) {
            // CSV 2of3, subtype is the number of CSV blocks
            written = scriptpubkey_csv_2of3_then_2_from_bytes(keys, subtype, 0, script);
        } else if (type == script_type::p2sh_p2wsh_csv_fortified_out) {
            // CSV 2of2, subtype is the number of CSV blocks
            written = scriptpubkey_csv_2of2_then_1_from_bytes(keys, subtype, 0, script);
        } else {
            // P2SH or P2SH-P2WSH standard 2of2/2of3 multisig
            written = scriptpubkey_multisig_from_bytes(keys, threshold, 0, script);
        }
        GA_SDK_RUNTIME_ASSERT(written <= script.size());
        script.resize(written);
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
        const size_t written = scriptsig_multisig_from_bytes(prevout_script, sigs, sighashes, 0, script);
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
        auto suffix = gsl::make_span(
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
        const uint32_t flags = WALLY_SCRIPT_SHA256 | WALLY_SCRIPT_AS_PUSH;
        std::array<unsigned char, 3 + SHA256_LEN> witness;
        GA_SDK_RUNTIME_ASSERT(witness_program_from_bytes(script, flags, witness) == witness.size());
        return witness;
    }

    std::vector<unsigned char> tx_to_bytes(const wally_tx_ptr& tx)
    {
        const uint32_t flags = WALLY_TX_FLAG_USE_WITNESS;
        std::vector<unsigned char> buff(tx_get_length(tx, flags));
        GA_SDK_RUNTIME_ASSERT(tx_to_bytes(tx, flags, buff) == buff.size());
        return buff;
    }

    amount get_tx_fee(const wally_tx_ptr& tx, amount min_fee_rate, amount fee_rate)
    {
        const amount rate = fee_rate < min_fee_rate ? min_fee_rate : fee_rate;

        const size_t vsize = tx_get_vsize(tx);
        const auto fee = static_cast<double>(vsize) * rate.value() / 1000.0;
        const auto rounded_fee = static_cast<amount::value_type>(std::ceil(fee));
        return amount(rounded_fee);
    }

    void add_tx_output(
        const network_parameters& net_params, wally_tx_ptr& tx, const std::string& address, uint32_t satoshi)
    {
        const auto output_script = output_script_for_address(net_params, address);
        tx_add_raw_output(tx, satoshi, output_script, 0);
    }

    void update_tx_info(const wally_tx_ptr& tx, nlohmann::json& result)
    {
        result["transaction"] = hex_from_bytes(tx_to_bytes(tx));
        const auto weight = tx_get_weight(tx);
        result["transaction_size"] = tx_get_length(tx, WALLY_TX_FLAG_USE_WITNESS);
        result["transaction_weight"] = weight;
        result["transaction_vsize"] = tx_vsize_from_weight(weight);
    }

    void set_anti_snipe_locktime(const wally_tx_ptr& tx, uint32_t current_block_height)
    {
        // We use cores algorithm to randomly use an older locktime for delayed tx privacy
        tx->locktime = current_block_height;
        if (get_uniform_uint32_t(10) == 0) {
            tx->locktime -= get_uniform_uint32_t(100);
        }
    }

} // namespace sdk
} // namespace ga
