#include "boost_wrapper.hpp"

#include "assertion.hpp"
#include "include/session.hpp"
#include "memory.hpp"
#include "transaction_utils.hpp"
#include "utils.hpp"
#include "xpub_hdkey.hpp"

namespace ga {
namespace sdk {
    // Dummy signatures are needed for correctly sizing transactions. If our signer supports
    // low-R signatures, we estimate on a 71 byte signature, and occasionally produce 70 byte
    // signatures. Otherwise, we estimate on 72 bytes and occasionally produce 70 or 71 byte
    // signatures. Worst-case overestimation is therefore 2 bytes per input * 2 sigs, or
    // 1 vbyte per input for segwit transactions.

    // We construct our dummy sigs R, S from OP_SUBSTR/OP_INVALIDOPCODE.
#define SIG_SLED(INITIAL, B) INITIAL, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B
#define SIG_BYTES(INITIAL, B) SIG_SLED(INITIAL, B), SIG_SLED(B, B)

#define SIG_HIGH SIG_BYTES(OP_INVALIDOPCODE, OP_SUBSTR)
#define SIG_LOW SIG_BYTES(OP_SUBSTR, OP_SUBSTR)

#define SIG_72(INITIAL, B) SIG_HIGH, SIG_HIGH
#define SIG_71(INITIAL, B) SIG_LOW, SIG_HIGH

    static const ecdsa_sig_t DUMMY_GA_SIG = { { SIG_HIGH, SIG_HIGH } };
    static const ecdsa_sig_t DUMMY_GA_SIG_LOW_R = { { SIG_LOW, SIG_HIGH } };

    // DER encodings of the above
    static const std::vector<unsigned char> DUMMY_GA_SIG_DER_PUSH
        = { { 0x00, 0x49, 0x30, 0x46, 0x02, 0x21, 0x00, SIG_HIGH, 0x02, 0x21, 0x00, SIG_HIGH, 0x01 } };
    static const std::vector<unsigned char> DUMMY_GA_SIG_DER_PUSH_LOW_R
        = { { 0x00, 0x49, 0x30, 0x45, 0x02, 0x20, SIG_LOW, 0x02, 0x21, 0x00, SIG_HIGH, 0x01 } };

    static const std::array<unsigned char, 3> OP_0_PREFIX = { { 0x00, 0x01, 0x00 } };

    static script_type get_script_type_from_address_type(const std::string& addr_type)
    {
        if (addr_type == address_type::csv)
            return script_type::p2sh_p2wsh_csv_fortified_out;
        if (addr_type == address_type::p2wsh)
            return script_type::p2sh_p2wsh_fortified_out;
        GA_SDK_RUNTIME_ASSERT(addr_type == address_type::p2sh);
        return script_type::p2sh_fortified_out;
    }

    inline auto p2sh_address_from_bytes(const network_parameters& net_params, byte_span_t script)
    {
        std::array<unsigned char, HASH160_LEN + 1> addr;
        const auto hash = hash160(script);
        addr[0] = net_params.btc_p2sh_version();
        std::copy(hash.begin(), hash.end(), addr.begin() + 1);
        return addr;
    }

    inline auto p2sh_p2wsh_address_from_bytes(const network_parameters& net_params, byte_span_t script)
    {
        return p2sh_address_from_bytes(net_params, witness_program_from_bytes(script, WALLY_SCRIPT_SHA256));
    }

    std::string get_address_from_script(
        const network_parameters& net_params, byte_span_t script, const std::string& addr_type)
    {
        if (addr_type == address_type::p2sh) {
            return base58check_from_bytes(p2sh_address_from_bytes(net_params, script));
        } else if (addr_type == address_type::p2wsh || addr_type == address_type::csv) {
            return base58check_from_bytes(p2sh_p2wsh_address_from_bytes(net_params, script));
        }
        GA_SDK_RUNTIME_ASSERT(false);
        __builtin_unreachable();
    }

    std::vector<unsigned char> output_script_for_address(
        const network_parameters& net_params, const std::string& address)
    {
        if (boost::starts_with(address, net_params.bech32_prefix())) {
            // Segwit v0 P2WPKH or P2WSH
            return addr_segwit_v0_to_bytes(address, net_params.bech32_prefix());
        } else {
            // Base58 encoded bitcoin address
            const auto addr_bytes = base58check_to_bytes(address);
            GA_SDK_RUNTIME_ASSERT(addr_bytes.size() == 1 + HASH160_LEN);
            const auto script_hash = gsl::make_span(addr_bytes).subspan(1, HASH160_LEN);

            if (addr_bytes.front() == net_params.btc_p2sh_version()) {
                return scriptpubkey_p2sh_from_hash160(script_hash);
            } else if (addr_bytes.front() == net_params.btc_version()) {
                return scriptpubkey_p2pkh_from_hash160(script_hash);
            } else {
                GA_SDK_RUNTIME_ASSERT(false); // Unknown address version
                __builtin_unreachable();
            }
        }
    }

    static std::vector<unsigned char> output_script(const pub_key_t& ga_pub_key, const pub_key_t& user_pub_key,
        gsl::span<const unsigned char> backup_pub_key, script_type type, uint32_t subtype)
    {
        const bool is_2of3 = !backup_pub_key.empty();

        size_t n_pubkeys = 2, threshold = 2;
        std::vector<unsigned char> keys;
        keys.reserve(3 * ga_pub_key.size());
        keys.insert(keys.end(), std::begin(ga_pub_key), std::end(ga_pub_key));
        keys.insert(keys.end(), std::begin(user_pub_key), std::end(user_pub_key));
        if (is_2of3) {
            GA_SDK_RUNTIME_ASSERT(static_cast<size_t>(backup_pub_key.size()) == ga_pub_key.size());
            keys.insert(keys.end(), std::begin(backup_pub_key), std::end(backup_pub_key));
            ++n_pubkeys;
        }

        const size_t max_script_len = 13 + n_pubkeys * (ga_pub_key.size() + 1) + 4;
        std::vector<unsigned char> script(max_script_len);

        if (type == script_type::p2sh_p2wsh_csv_fortified_out && is_2of3) {
            // CSV 2of3, subtype is the number of CSV blocks
            scriptpubkey_csv_2of3_then_2_from_bytes(keys, subtype, script);
        } else if (type == script_type::p2sh_p2wsh_csv_fortified_out) {
            // CSV 2of2, subtype is the number of CSV blocks
            scriptpubkey_csv_2of2_then_1_from_bytes(keys, subtype, script);
        } else {
            // P2SH or P2SH-P2WSH standard 2of2/2of3 multisig
            scriptpubkey_multisig_from_bytes(keys, threshold, script);
        }
        return script;
    }

    std::vector<unsigned char> output_script(ga_pubkeys& pubkeys, ga_user_pubkeys& user_pubkeys,
        ga_user_pubkeys& recovery_pubkeys, uint32_t subaccount, const nlohmann::json& data)
    {
        const uint32_t pointer = data["pointer"];
        script_type type;

        auto addr_type = data.find("addr_type");
        if (addr_type != data.end()) {
            // Address
            // TODO: get script_type from returned address (requires server support)
            type = get_script_type_from_address_type(*addr_type);
        } else {
            type = data["script_type"];
        }
        uint32_t subtype = 0;
        if (type == script_type::p2sh_p2wsh_csv_fortified_out)
            subtype = data["subtype"];

        const auto ga_pub_key = pubkeys.derive(subaccount, pointer);
        const auto user_pub_key = user_pubkeys.derive(subaccount, pointer);

        if (recovery_pubkeys.have_subaccount(subaccount)) {
            // 2of3
            return output_script(ga_pub_key, user_pub_key, recovery_pubkeys.derive(subaccount, pointer), type, subtype);
        } else {
            // 2of2
            return output_script(ga_pub_key, user_pub_key, empty_span(), type, subtype);
        }
    }

    std::vector<unsigned char> input_script(signer& user_signer, const std::vector<unsigned char>& prevout_script,
        const ecdsa_sig_t& user_sig, const ecdsa_sig_t& ga_sig)
    {
        const std::array<uint32_t, 2> sighashes = { { WALLY_SIGHASH_ALL, WALLY_SIGHASH_ALL } };
        std::array<unsigned char, sizeof(ecdsa_sig_t) * 2> sigs;
        init_container(sigs, ga_sig, user_sig);
        const uint32_t sig_len
            = user_signer.supports_low_r() ? EC_SIGNATURE_DER_MAX_LEN : EC_SIGNATURE_DER_MAX_LOW_R_LEN;
        std::vector<unsigned char> script(1 + (sig_len + 2) * 2 + 3 + prevout_script.size());
        scriptsig_multisig_from_bytes(prevout_script, sigs, sighashes, script);
        return script;
    }

    std::vector<unsigned char> input_script(
        signer& user_signer, const std::vector<unsigned char>& prevout_script, const ecdsa_sig_t& user_sig)
    {
        const ecdsa_sig_t& dummy_sig = user_signer.supports_low_r() ? DUMMY_GA_SIG_LOW_R : DUMMY_GA_SIG;
        const std::vector<unsigned char>& dummy_push
            = user_signer.supports_low_r() ? DUMMY_GA_SIG_DER_PUSH_LOW_R : DUMMY_GA_SIG_DER_PUSH;

        std::vector<unsigned char> full_script = input_script(user_signer, prevout_script, user_sig, dummy_sig);
        // Replace the dummy sig with PUSH(0)
        GA_SDK_RUNTIME_ASSERT(std::search(full_script.begin(), full_script.end(), dummy_push.begin(), dummy_push.end())
            == full_script.begin());
        auto suffix = gsl::make_span(full_script).subspan(dummy_push.size());

        std::vector<unsigned char> script(OP_0_PREFIX.size() + suffix.size());
        init_container(script, OP_0_PREFIX, suffix);
        return script;
    }

    std::vector<unsigned char> dummy_input_script(signer& user_signer, const std::vector<unsigned char>& prevout_script)
    {
        const ecdsa_sig_t& dummy_sig = user_signer.supports_low_r() ? DUMMY_GA_SIG_LOW_R : DUMMY_GA_SIG;
        return input_script(user_signer, prevout_script, dummy_sig, dummy_sig);
    }

    std::vector<unsigned char> witness_script(const std::vector<unsigned char>& script)
    {
        return witness_program_from_bytes(script, WALLY_SCRIPT_SHA256 | WALLY_SCRIPT_AS_PUSH);
    }

    amount get_tx_fee(const wally_tx_ptr& tx, amount min_fee_rate, amount fee_rate)
    {
        const amount rate = fee_rate < min_fee_rate ? min_fee_rate : fee_rate;

        const size_t vsize = tx_get_vsize(tx);
        const auto fee = static_cast<double>(vsize) * rate.value() / 1000.0;
        const auto rounded_fee = static_cast<amount::value_type>(std::ceil(fee));
        return amount(rounded_fee);
    }

    amount add_tx_output(
        const network_parameters& net_params, wally_tx_ptr& tx, const std::string& address, uint32_t satoshi)
    {
        // FIXME: Support OP_RETURN outputs
        tx_add_raw_output(tx, satoshi, output_script_for_address(net_params, address));
        return amount(satoshi);
    }

    amount add_tx_addressee(session& session, const network_parameters& net_params, wally_tx_ptr& tx,
        nlohmann::json& result, const nlohmann::json& addressee)
    {
        std::string address = addressee.at("address");
        nlohmann::json amount;
        nlohmann::json payment_uri_params = parse_bitcoin_uri(address);
        if (!payment_uri_params.is_null()) {
            result["bip21"] = payment_uri_params;
            address = payment_uri_params.at("address");
            amount = session.convert_amount({ { "btc", payment_uri_params["amount"] } });
        } else {
            amount = session.convert_amount(addressee);
        }
        return add_tx_output(net_params, tx, address, amount["satoshi"]);
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
