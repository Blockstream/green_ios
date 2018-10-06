#include <array>
#include <map>
#include <string>
#include <thread>
#include <vector>

#include <gsl/span>

#include "boost_wrapper.hpp"
#include "include/exception.hpp"
#include "include/session.hpp"

#include "autobahn_wrapper.hpp"
#include "ga_session.hpp"
#include "logging.hpp"
#include "memory.hpp"
#include "transaction_utils.hpp"
#include "utils.hpp"

namespace ga {
namespace sdk {
    boost::log::sources::logger_mt& websocket_boost_logger::m_log = gdk_logger::get();

    namespace {
        static const std::string DEFAULT_USER_AGENT("[v2,sw,csv]");
        static const unsigned char GA_LOGIN_NONCE[30] = { 'G', 'r', 'e', 'e', 'n', 'A', 'd', 'd', 'r', 'e', 's', 's',
            '.', 'i', 't', ' ', 'H', 'D', ' ', 'w', 'a', 'l', 'l', 'e', 't', ' ', 'p', 'a', 't', 'h' };
        // TODO: The server should return these
        static const std::vector<std::string> ALL_2FA_METHODS = { { "email" }, { "sms" }, { "phone" }, { "gauth" } };

        static const std::string MASKED_GAUTH_SEED("***");

        static const uint32_t DEFAULT_MIN_FEE = 1000; // 1 satoshi/byte
        static const uint32_t NUM_FEE_ESTIMATES = 25; // Min fee followed by blocks 1-24

        static std::once_flag one_time_setup_flag;

        static void one_time_setup()
        {
            std::call_once(one_time_setup_flag, [] {
                wally::init(0);
                wally::secp_randomize(get_random_bytes<WALLY_SECP_RANDOMIZE_LEN>());
            });
        }

        // FIXME: too slow. lacks validation.
        static std::array<unsigned char, 32> uint256_to_base256(const std::string& input)
        {
            constexpr size_t base = 256;

            std::array<unsigned char, 32> repr;
            size_t i = repr.size() - 1;
            for (boost::multiprecision::checked_uint256_t num(input); num; num = num / base, --i) {
                repr[i] = static_cast<unsigned char>(num % base);
            }

            return repr;
        }

        static void get_pin_key(const std::vector<unsigned char>& password, const std::string& salt,
            std::array<unsigned char, PBKDF2_HMAC_SHA256_LEN>& out)
        {
            const auto salt_bytes = gsl::make_span(reinterpret_cast<const unsigned char*>(salt.data()), salt.size());
            pbkdf2_hmac_sha512_256(password, salt_bytes, 0, 2048, out);
        }

        template <typename T> static nlohmann::json get_json_result(const T& result)
        {
            auto obj = result.template argument<msgpack::object>(0);
            std::stringstream ss;
            ss << obj;
            return nlohmann::json::parse(ss.str());
        }

        static nlohmann::json get_fees_as_json(const autobahn::wamp_event& event)
        {
            auto obj = event.argument<msgpack::object>(0);
            std::stringstream ss;
            ss << obj;
            std::string fee_json = ss.str();
            // FIXME: Remove this once the server is fixed to use string keys
            fee_json.reserve(fee_json.size() + 6 * 2); // 6 pairs of quotes
            boost::algorithm::replace_first(fee_json, "1:", "\"1\":");
            boost::algorithm::replace_first(fee_json, "2:", "\"2\":");
            boost::algorithm::replace_first(fee_json, "3:", "\"3\":");
            boost::algorithm::replace_first(fee_json, "6:", "\"6\":");
            boost::algorithm::replace_first(fee_json, "12:", "\"12\":");
            boost::algorithm::replace_first(fee_json, "24:", "\"24\":");
            return nlohmann::json::parse(fee_json);
        }

        static msgpack::object_handle as_messagepack(const nlohmann::json& json)
        {
            if (json.is_null()) {
                return msgpack::object_handle();
            } else {
                const auto buffer = nlohmann::json::to_msgpack(json);
                return msgpack::unpack(reinterpret_cast<const char*>(buffer.data()), buffer.size());
            }
        }

        static auto get_subaccount_master_key(const wally_ext_key_ptr& master_key, uint32_t subaccount)
        {
            GA_SDK_RUNTIME_ASSERT(subaccount != 0);
            const bool public_ = false;
            return derive_key(master_key,
                std::array<uint32_t, 2>{
                    { BIP32_INITIAL_HARDENED_CHILD | 3, BIP32_INITIAL_HARDENED_CHILD | subaccount } },
                public_);
        }

        static auto get_subaccount_master_xpub(const wally_ext_key_ptr& master_key, uint32_t subaccount)
        {
            const auto subkey = get_subaccount_master_key(master_key, subaccount);
            return std::make_pair(
                hex_from_bytes(gsl::make_span(subkey->pub_key)), hex_from_bytes(gsl::make_span(subkey->chain_code)));
        }

        static auto get_recovery_key(const wally_ext_key_ptr& hdkey, const std::string& xpub, uint32_t subaccount)
        {
            std::string pub_key, chain_code;
            std::tie(pub_key, chain_code) = get_subaccount_master_xpub(hdkey, subaccount);
            return std::make_tuple(pub_key, chain_code, xpub);
        }

        static auto get_recovery_key(const std::string& mnemonic, uint32_t bip32_version, uint32_t subaccount)
        {
            bip39_mnemonic_validate(nullptr, mnemonic);

            // FIXME: secure_array
            std::array<unsigned char, BIP39_SEED_LEN_512> seed;
            GA_SDK_RUNTIME_ASSERT(bip39_mnemonic_to_seed(mnemonic, nullptr, seed) == seed.size());

            ext_key* p;
            bip32_key_from_seed_alloc(seed, bip32_version, BIP32_FLAG_SKIP_HASH, &p);
            wally_ext_key_ptr hdkey(p);
            std::array<unsigned char, BIP32_SERIALIZED_LEN> xpub_bytes;
            bip32_key_serialize(hdkey, BIP32_FLAG_KEY_PUBLIC, xpub_bytes);
            return get_recovery_key(hdkey, base58check_from_bytes(xpub_bytes), subaccount);
        }

        static auto get_recovery_key(const std::string& xpub, uint32_t subaccount)
        {
            std::array<unsigned char, BIP32_SERIALIZED_LEN + BASE58_CHECKSUM_LEN> xpub_bytes;
            GA_SDK_RUNTIME_ASSERT(base58check_to_bytes(xpub, xpub_bytes) == BIP32_SERIALIZED_LEN);

            ext_key* p;
            bip32_key_unserialize_alloc(gsl::make_span(xpub_bytes.data(), BIP32_SERIALIZED_LEN), &p);
            return get_recovery_key(wally_ext_key_ptr(p), xpub, subaccount);
        }

        static std::string get_address_from_script(const network_parameters& net_params,
            const std::vector<unsigned char>& script, const std::string& addr_type)
        {
            if (addr_type == address_type::p2sh) {
                return base58check_from_bytes(p2sh_address_from_bytes(net_params, script));
            } else if (addr_type == address_type::p2wsh || addr_type == address_type::csv) {
                return base58check_from_bytes(p2sh_p2wsh_address_from_bytes(net_params, script));
            }
            GA_SDK_RUNTIME_ASSERT(false);
            __builtin_unreachable();
        }

        static script_type get_script_type_from_address_type(const std::string& addr_type)
        {
            if (addr_type == address_type::csv)
                return script_type::p2sh_p2wsh_csv_fortified_out;
            if (addr_type == address_type::p2wsh)
                return script_type::p2sh_p2wsh_fortified_out;
            GA_SDK_RUNTIME_ASSERT(addr_type == address_type::p2sh);
            return script_type::p2sh_fortified_out;
        }

        static nlohmann::json cleanup_utxos(nlohmann::json& utxos)
        {
            for (auto& utxo : utxos) {
                // Clean up the type of returned values
                utxo["satoshi"] = boost::lexical_cast<amount::value_type>(json_get_value(utxo, "value"));
                utxo.erase("value");
            }
            return utxos;
        }

        static std::string sign_hash(const wally_ext_key_ptr& master_key, const std::vector<uint32_t>& path,
            const std::array<unsigned char, 32>& hash)
        {
            // FIXME: secure_array
            std::array<unsigned char, EC_PRIVATE_KEY_LEN> login_priv_key;
            derive_private_key(master_key, path, login_priv_key);

            std::array<unsigned char, EC_SIGNATURE_LEN> sig;
            ec_sig_from_bytes(login_priv_key, hash, EC_FLAG_ECDSA | EC_FLAG_GRIND_R, sig);

            return hex_from_bytes(ec_sig_to_der(sig));
        }

    } // namespace

    uint32_t websocket_rng_type::operator()() const
    {
        uint32_t b;
        get_random_bytes(sizeof(b), &b, sizeof(b));
        return b;
    }

    event_loop_controller::event_loop_controller(boost::asio::io_service& io)
        : m_work_guard(std::make_unique<boost::asio::io_service::work>(io))
    {
        m_run_thread = std::thread([&] { io.run(); });
    }

    event_loop_controller::~event_loop_controller()
    {
        m_work_guard.reset();
        m_run_thread.join();
    }

    ga_session::ga_session(network_parameters net_params, bool debug)
        : m_controller(m_io)
        , m_net_params(std::move(net_params))
        , m_min_fee_rate(DEFAULT_MIN_FEE)
        , m_next_subaccount(0)
        , m_block_height(0)
        , m_master_key(nullptr)
        , m_system_message_id(0)
        , m_system_message_ack_id(0)
        , m_watch_only(true)
        , m_rfc2818_verifier(websocketpp::uri(m_net_params.gait_wamp_url()).get_host())
        , m_cert_pin_validated(false)
        , m_debug(debug)
    {
        one_time_setup();
        m_fee_estimates.assign(NUM_FEE_ESTIMATES, m_min_fee_rate);
        connect_with_tls() ? make_client<client_tls>() : make_client<client>();
    }

    ga_session::~ga_session()
    {
        reset();
        m_io.stop();
    }

    void ga_session::unsubscribe()
    {
        for (const auto& sub : m_subscriptions) {
            no_std_exception_escape([this, &sub] { m_session->unsubscribe(sub).get(); });
        }
        m_subscriptions.clear();
    }

    bool ga_session::connect_with_tls() const
    {
        return boost::algorithm::starts_with(
            !m_net_params.get_use_tor() ? m_net_params.gait_wamp_url() : m_net_params.gait_onion(), "wss://");
    }

    void ga_session::connect()
    {
        m_session = std::make_shared<autobahn::wamp_session>(m_io, m_debug);

        const bool tls = connect_with_tls();
        tls ? make_transport<transport_tls>() : make_transport<transport>();
        tls ? connect_to_endpoint<transport_tls>() : connect_to_endpoint<transport>();
    }

    void ga_session::connect_to_endpoint_impl(
        std::array<boost::future<void>, 3>& futures, boost::future<void>& connected) const
    {
        connected.get();
        futures[1] = m_session->start().then([&](boost::future<void> started) {
            started.get();
            futures[2] = m_session->join("realm1").then([&](boost::future<uint64_t> joined) { joined.get(); });
        });
    }

    context_ptr ga_session::tls_init_handler_impl()
    {
        const context_ptr ctx = std::make_shared<boost::asio::ssl::context>(boost::asio::ssl::context::tlsv12);
        ctx->set_options(boost::asio::ssl::context::default_workarounds | boost::asio::ssl::context::no_sslv2
            | boost::asio::ssl::context::no_sslv3 | boost::asio::ssl::context::no_tlsv1
            | boost::asio::ssl::context::no_tlsv1_1 | boost::asio::ssl::context::single_dh_use);
        ctx->set_verify_mode(
            boost::asio::ssl::context::verify_peer | boost::asio::ssl::context::verify_fail_if_no_peer_cert);
        // attempt to load system roots
        ctx->set_default_verify_paths();
        const auto& roots = m_net_params.gait_wamp_cert_roots();
        for (const auto& root : roots) {
            if (root.empty()) {
                // FIXME: at the moment looks like the roots/pins are empty string when absent
                break;
            }
            // add network provided root
            const boost::asio::const_buffer root_const_buff(root.c_str(), root.size());
            ctx->add_certificate_authority(root_const_buff);
        }
        const auto& pins = m_net_params.gait_wamp_cert_pins();
        if (pins.empty() || pins[0].empty()) {
            // no pins for this network, just do rfc2818 validation
            ctx->set_verify_callback(m_rfc2818_verifier);
            return ctx;
        }

        ctx->set_verify_callback([this](bool preverified, boost::asio::ssl::verify_context& ctx) {
            if (!preverified) {
                return false;
            }
            const auto cert = X509_STORE_CTX_get_current_cert(ctx.native_handle());
            if (!cert) {
                return false;
            }
            std::array<unsigned char, SHA256_LEN> buf;
            unsigned int written = 0;
            if (!X509_digest(cert, EVP_sha256(), buf.data(), &written) || written != buf.size()) {
                return false;
            }
            const auto& pins = m_net_params.gait_wamp_cert_pins();
            const auto hex_digest = hex_from_bytes(buf);
            if (std::find(pins.begin(), pins.end(), hex_digest) != pins.end()) {
                m_cert_pin_validated = true;
            }
            // on top of rfc2818, enforce pin if this is the last cert in the chain
            const int depth = X509_STORE_CTX_get_error_depth(ctx.native_handle());
            return m_rfc2818_verifier(m_cert_pin_validated || depth != 0, ctx);
        });

        return ctx;
    }

    void ga_session::disconnect() const
    {
        no_std_exception_escape([this] { m_session->leave().get(); });
        no_std_exception_escape([this] { m_session->stop().get(); });
        connect_with_tls() ? disconnect_transport<transport_tls>() : disconnect_transport<transport>();
    }

    void ga_session::reset()
    {
        m_mnemonic.clear(); // FIXME: securely clear
        unsubscribe();
        disconnect();
        // FIXME: securely destroy all held data
    }

    uint32_t ga_session::get_bip32_version() const
    {
        return m_net_params.main_net() ? BIP32_VER_MAIN_PRIVATE : BIP32_VER_TEST_PRIVATE;
    }

    std::pair<std::string, std::string> ga_session::sign_challenge(
        const wally_ext_key_ptr& master_key, const std::string& challenge)
    {
        auto path_bytes = get_random_bytes<8>();

        std::vector<uint32_t> path(4);
        adjacent_transform(std::begin(path_bytes), std::end(path_bytes), std::begin(path),
            [](auto first, auto second) { return uint32_t((first << 8) + second); });

        const auto challenge_hash = uint256_to_base256(challenge);

        return { sign_hash(master_key, path, challenge_hash), hex_from_bytes(path_bytes) };
    }

    void ga_session::set_fee_estimates(const nlohmann::json& fee_estimates)
    {
        // Convert server estimates into an array of NUM_FEE_ESTIMATES estimates
        // ordered by block, with the minimum allowable fee at position 0
        std::map<uint32_t, uint32_t> ordered_estimates;
        for (const auto& e : fee_estimates) {
            const auto& feerate = e["feerate"];
            double btc_per_k;
            if (feerate.is_string()) {
                const std::string feerate_str = feerate;
                btc_per_k = boost::lexical_cast<double>(feerate_str);
            } else {
                btc_per_k = feerate;
            }
            if (btc_per_k > 0) {
                const uint32_t actual_block = e["blocks"];
                if (actual_block > 0 && actual_block <= NUM_FEE_ESTIMATES - 1) {
                    const long long satoshi_per_k = std::lround(btc_per_k * amount::coin_value);
                    const long long uint32_t_max = std::numeric_limits<uint32_t>::max();
                    if (satoshi_per_k >= DEFAULT_MIN_FEE && satoshi_per_k <= uint32_t_max) {
                        ordered_estimates[actual_block] = static_cast<uint32_t>(satoshi_per_k);
                    }
                }
            }
        }

        std::vector<uint32_t> new_estimates(NUM_FEE_ESTIMATES);
        new_estimates[0] = m_min_fee_rate;
        size_t i = 1;
        for (const auto& e : ordered_estimates) {
            while (i <= e.first) {
                new_estimates[i] = e.second;
                ++i;
            }
        }

        if (i == 1u) {
            // No usable estimates, use existing ones until new ones arrive
            return;
        }

        while (i < NUM_FEE_ESTIMATES) {
            new_estimates[i] = new_estimates[i - 1];
            ++i;
        }

        // FIXME locking for m_fee_estimates
        std::swap(m_fee_estimates, new_estimates);
    }

    void ga_session::register_user(const std::string& mnemonic, const std::string& user_agent)
    {
        // Only the English word list is supported. This check is important because bip39_mnemonic_to_seed
        // does not do any validation (by design)
        bip39_mnemonic_validate(nullptr, mnemonic);

        // FIXME: secure_array
        std::array<unsigned char, BIP39_SEED_LEN_512> seed;
        GA_SDK_RUNTIME_ASSERT(bip39_mnemonic_to_seed(mnemonic, nullptr, seed) == seed.size());

        ext_key master;
        bip32_key_from_seed(seed, get_bip32_version(), BIP32_FLAG_SKIP_HASH, &master);
        // Since we don't use the private key or seed further, wipe them immediately
        wally::clear(static_cast<unsigned char*>(master.priv_key), sizeof(master.priv_key));
        wally::clear(seed);

        std::array<unsigned char, sizeof(master.chain_code) + sizeof(master.pub_key)> path_data;
        init_container(path_data, gsl::make_span(master.chain_code), gsl::make_span(master.pub_key));

        std::array<unsigned char, HMAC_SHA512_LEN> path;
        hmac_sha512(gsl::make_span(GA_LOGIN_NONCE), path_data, path);

        const auto pub_key = hex_from_bytes(gsl::make_span(master.pub_key));
        const auto chain_code = hex_from_bytes(gsl::make_span(master.chain_code));
        const auto hex_path = hex_from_bytes(path);
        const auto ua = DEFAULT_USER_AGENT + user_agent + "_ga_sdk";

        wamp_call([](wamp_call_result result) { GA_SDK_RUNTIME_ASSERT(result.get().argument<bool>(0)); },
            "com.greenaddress.login.register", pub_key, chain_code, ua, hex_path);
    }

    void ga_session::update_login_data(nlohmann::json&& login_data, bool watch_only)
    {
        m_login_data = login_data;

        const uint32_t min_fee_rate = m_login_data["min_fee"];
        if (min_fee_rate != m_min_fee_rate) {
            m_min_fee_rate = min_fee_rate;
            m_fee_estimates.assign(NUM_FEE_ESTIMATES, m_min_fee_rate);
        }
        m_fiat_source = login_data["exchange"];
        m_fiat_currency = login_data["fiat_currency"];
        m_fiat_rate = login_data["fiat_exchange"];

        const uint32_t block_height = m_login_data["block_height"];
        m_block_height = block_height;

        m_subaccounts.clear();
        m_next_subaccount = 0;
        for (const auto& subaccount : m_login_data["subaccounts"]) {
            const uint32_t pointer = subaccount["pointer"];
            std::string type = subaccount["type"];
            if (type == "simple")
                type = "2of2";
            insert_subaccount(subaccount["name"], pointer, subaccount["receiving_id"],
                json_get_value(subaccount, "2of3_backup_pubkey", std::string()),
                json_get_value(subaccount, "2of3_backup_chaincode", std::string()), type,
                subaccount.value("has_txs", false));
            if (pointer > m_next_subaccount)
                m_next_subaccount = pointer;
        }
        ++m_next_subaccount;

        // Insert the main account so callers can treat all accounts equally
        const bool has_txs = m_login_data.value("has_txs", false);
        insert_subaccount(
            std::string(), 0, m_login_data["receiving_id"], std::string(), std::string(), "2of2", has_txs);

        m_system_message_id = m_login_data.value("next_system_message_id", 0);
        m_system_message_ack_id = 0;
        m_system_message_ack = std::string();
        m_watch_only = watch_only;

        set_fee_estimates(m_login_data["fee_estimates"]);
        const auto p = m_login_data.find("limits");
        update_spending_limits(p == m_login_data.end() ? nlohmann::json() : *p);
    }

    void ga_session::update_spending_limits(const nlohmann::json& limits)
    {
        // FIXME: locking, set on server
        if (limits.is_null()) {
            m_limits_data = { { "is_fiat", false }, { "per_tx", 0 }, { "total", 0 } };
        } else {
            m_limits_data = limits;
        }
    }

    nlohmann::json ga_session::get_spending_limits() const
    {
        // FIXME: locking
        const auto& total_p = m_limits_data["total"];
        amount::value_type total;
        if (total_p.is_number()) {
            total = total_p;
        } else {
            const std::string total_str = total_p;
            total = strtoul(total_str.c_str(), NULL, 10);
        }

        nlohmann::json converted_limits;
        const bool is_fiat = m_limits_data["is_fiat"];
        if (is_fiat) {
            converted_limits = convert_fiat_cents(total);
        } else {
            converted_limits = convert_amount({ { "satoshi", total } });
        }
        converted_limits["is_fiat"] = is_fiat;
        return converted_limits;
    }

    void ga_session::on_new_transaction(const nlohmann::json& details)
    {
        // FIXME: Update have_transactions in each affected subaccount,
        // mark cached tx lists (when implemented) as dirty, and notify the user
        (void)details;
    }

    void ga_session::login(const std::string& mnemonic, const std::string& user_agent)
    {
        GDK_LOG_NAMED_SCOPE("login");

        GA_SDK_RUNTIME_ASSERT_MSG(!m_master_key, "re-login on an existing session always fails");

        bip39_mnemonic_validate(nullptr, mnemonic);

        // FIXME: secure_array
        std::array<unsigned char, BIP39_SEED_LEN_512> seed;
        GA_SDK_RUNTIME_ASSERT(bip39_mnemonic_to_seed(mnemonic, nullptr, seed) == seed.size());

        // FIXME: Allocate m_master_key in mlocked memory and pass it
        ext_key* p;
        bip32_key_from_seed_alloc(seed, get_bip32_version(), 0, &p);

        m_master_key = wally_ext_key_ptr(p);

        unsigned char btc_ver[1] = { m_net_params.btc_version() };
        std::array<unsigned char, sizeof(btc_ver) + sizeof(m_master_key->hash160)> vpkh;
        init_container(vpkh, gsl::make_span(btc_ver), gsl::make_span(m_master_key->hash160));

        std::string challenge;
        wamp_call([&challenge](wamp_call_result result) { challenge = result.get().argument<std::string>(0); },
            "com.greenaddress.login.get_challenge", base58check_from_bytes(vpkh));

        const auto hexder_path = sign_challenge(m_master_key, challenge);
        wamp_call([this](wamp_call_result result) { update_login_data(get_json_result(result.get()), false); },
            "com.greenaddress.login.authenticate", hexder_path.first, false, hexder_path.second,
            std::string("fake_dev_id"), DEFAULT_USER_AGENT + user_agent + "_ga_sdk");

        m_mnemonic = mnemonic;

        const std::string receiving_id = m_login_data["receiving_id"];
        m_subscriptions.emplace_back(subscribe("com.greenaddress.txs.wallet_" + receiving_id,
            [this](const autobahn::wamp_event& event) { on_new_transaction(get_json_result(event)); }));

        m_subscriptions.emplace_back(subscribe("com.greenaddress.blocks", [this](const autobahn::wamp_event& event) {
            const nlohmann::json block_ev = get_json_result(event);
            const uint32_t block_height = block_ev["count"];
            GA_SDK_RUNTIME_ASSERT(block_height >= m_block_height);
            m_block_height = block_height;
        }));

        m_subscriptions.emplace_back(subscribe("com.greenaddress.fee_estimates",
            [this](const autobahn::wamp_event& event) { set_fee_estimates(get_fees_as_json(event)); }));

        if (m_login_data.value("segwit_server", true) && !m_login_data["appearance"].value("use_segwit", false)) {
            // Enable segwit
            m_login_data["appearance"]["use_segwit"] = true;

            /* FIXME: Server doesn't return a value in all envs yet
            bool r;
            wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            */
            wamp_call([](wamp_call_result result) { result.get(); }, "com.greenaddress.login.set_appearance",
                as_messagepack(m_login_data["appearance"]).get());
            // FIXME GA_SDK_RUNTIME_ASSERT(r);
        }
    }

    void ga_session::login(const std::string& pin, const nlohmann::json& pin_data, const std::string& user_agent)
    {
        // FIXME: clear password after use
        const auto password = get_pin_password(pin, pin_data["pin_identifier"]);

        const auto encrypted = bytes_from_hex(pin_data["encrypted_data"]);
        const auto iv = gsl::make_span(encrypted.data(), AES_BLOCK_LEN);
        const auto ciphertext = gsl::make_span(encrypted.data() + iv.size(), encrypted.size() - iv.size());

        std::array<unsigned char, PBKDF2_HMAC_SHA256_LEN> key;
        get_pin_key(password, pin_data["salt"], key);

        std::vector<unsigned char> plaintext(ciphertext.size());
        const auto written = aes_cbc(key, iv, ciphertext, AES_FLAG_DECRYPT, plaintext);
        GA_SDK_RUNTIME_ASSERT(written <= plaintext.size());

        // FIXME: clear data somehow?
        const auto data = nlohmann::json::parse(std::begin(plaintext), std::begin(plaintext) + written);

        m_mnemonic = data["mnemonic"];

        // FIXME: log in directly from the seed instead of the mnemonic
        login(m_mnemonic, user_agent);
    }

    void ga_session::login_watch_only(
        const std::string& username, const std::string& password, const std::string& user_agent)
    {
        const std::map<std::string, std::string> args = { { "username", username }, { "password", password } };
        wamp_call([this](wamp_call_result result) { update_login_data(get_json_result(result.get()), true); },
            "com.greenaddress.login.watch_only_v2", "custom", args, DEFAULT_USER_AGENT + user_agent + "_ga_sdk");
    }

    nlohmann::json ga_session::get_fee_estimates()
    {
        // FIXME: locking, augment with last_updated, user preference for display?
        return { { "estimates", m_fee_estimates } };
    }

    std::string ga_session::get_mnemonic_passphrase(const std::string& password)
    {
        GA_SDK_RUNTIME_ASSERT(!is_watch_only());
        GA_SDK_RUNTIME_ASSERT(password.empty()); // FIXME: Implement encryption
        GA_SDK_RUNTIME_ASSERT(!m_mnemonic.empty());
        return m_mnemonic;
    }

    std::string ga_session::get_system_message()
    {
        if (!m_system_message_ack.empty())
            return m_system_message_ack; // Existing unacked message

        if (is_watch_only() || m_system_message_id == 0)
            return std::string(); // Watch-only user, or no outstanding messages

        // Get the next message to ack
        nlohmann::json details;
        wamp_call([&details](wamp_call_result result) { details = get_json_result(result.get()); },
            "com.greenaddress.login.get_system_message", m_system_message_id);

        // Note the inconsistency with login_data key "next_system_message_id":
        // We don't rename the key as we don't expose the details JSON to callers
        m_system_message_id = details["next_message_id"];
        m_system_message_ack_id = details["message_id"];
        m_system_message_ack = details["message"];
        return m_system_message_ack;
    }

    void ga_session::ack_system_message(const std::string& message)
    {
        GA_SDK_RUNTIME_ASSERT(!message.empty() && message == m_system_message_ack);

        std::array<unsigned char, SHA256_LEN> message_hash;
        sha256d(std::vector<unsigned char>(message.begin(), message.end()), message_hash);

        const auto message_hash_hex = hex_from_bytes(message_hash);
        const auto ls_uint32_hex = message_hash_hex.substr(message_hash_hex.length() - 8);
        const uint32_t ls_uint32 = std::stoul(ls_uint32_hex, nullptr, 16);
        static const auto unharden = ~(0x01 << 31);
        const std::vector<uint32_t> path = { { 0x4741b11e, 6, ls_uint32 & unharden } };

        std::vector<unsigned char> message_hex_bytes(message_hash_hex.begin(), message_hash_hex.end());
        std::array<unsigned char, SHA256_LEN> hash;
        const size_t written = format_bitcoin_message(message_hex_bytes, BITCOIN_MESSAGE_FLAG_HASH, hash);
        GA_SDK_RUNTIME_ASSERT(written == hash.size());
        const auto signature = sign_hash(m_master_key, path, hash);

        wamp_call([](wamp_call_result result) { GA_SDK_RUNTIME_ASSERT(result.get().argument<bool>(0)); },
            "com.greenaddress.login.ack_system_message", m_system_message_ack_id, message_hash_hex, signature);
        m_system_message_ack = std::string();
    }

    nlohmann::json ga_session::convert_amount(const nlohmann::json& amount_json) const
    {
        return amount::convert(amount_json, m_fiat_currency, m_fiat_rate);
    }

    nlohmann::json ga_session::convert_fiat_cents(amount::value_type fiat_cents) const
    {
        return amount::convert_fiat_cents(fiat_cents, m_fiat_currency, m_fiat_rate);
    }

    nlohmann::json ga_session::encrypt(const nlohmann::json& input_json) const
    {
        if (is_watch_only() && input_json.find("key") == input_json.end()) {
            GA_SDK_RUNTIME_ASSERT_MSG(false, "A key must be provided to encrypt in watch-only mode");
        }

        // FIXME: Issue 47
        // Implement AES encryption, using input_json["key"] if given,
        // otherwise a privately derived key.
        return { { "plaintext", input_json.at("ciphertext") } };
    }

    nlohmann::json ga_session::decrypt(const nlohmann::json& input_json) const
    {
        if (is_watch_only() && input_json.find("key") == input_json.end()) {
            GA_SDK_RUNTIME_ASSERT_MSG(false, "A key must be provided to decrypt in watch-only mode");
        }

        // FIXME: Issue 47
        // Implement AES decryption, using input_json["key"] if given,
        // otherwise a privately derived key.
        return { { "ciphertext", input_json.at("plaintext") } };
    }

    bool ga_session::set_watch_only(const std::string& username, const std::string& password)
    {
        bool r;
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.addressbook.sync_custom", username, password);
        return r;
    }

    bool ga_session::remove_account(const nlohmann::json& twofactor_data)
    {
        bool r;
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.login.remove_account", as_messagepack(twofactor_data).get());
        return r;
    }

    nlohmann::json ga_session::get_subaccounts() const
    {
        std::vector<nlohmann::json> subaccounts;
        subaccounts.reserve(m_subaccounts.size());
        for (auto s : m_subaccounts)
            subaccounts.emplace_back(s.second);
        return nlohmann::json(subaccounts);
    }

    nlohmann::json ga_session::get_subaccount(uint32_t subaccount) const
    {
        const auto p = m_subaccounts.find(subaccount);
        GA_SDK_RUNTIME_ASSERT(p != m_subaccounts.end());
        return p->second;
    }

    nlohmann::json ga_session::insert_subaccount(const std::string& name, uint32_t pointer,
        const std::string& receiving_id, const std::string& recovery_pub_key, const std::string& recovery_chain_code,
        const std::string& type, bool has_txs)
    {
        GA_SDK_RUNTIME_ASSERT(m_subaccounts.find(pointer) == m_subaccounts.end());
        GA_SDK_RUNTIME_ASSERT(type == "2of2" || type == "2of3");

        nlohmann::json subaccount = { { "name", name }, { "pointer", pointer }, { "receiving_id", receiving_id },
            { "type", type }, { "recovery_pub_key", recovery_pub_key }, { "recovery_chain_code", recovery_chain_code },
            { "has_transactions", has_txs } };
        m_subaccounts[pointer] = subaccount;
        return subaccount;
    }

    nlohmann::json ga_session::create_subaccount(const nlohmann::json& details)
    {
        const std::string name = details.at("name");
        const std::string type = details.at("type");
        std::string recovery_mnemonic;
        std::string pub_key;
        std::string chain_code;
        std::string recovery_pub_key;
        std::string recovery_chain_code;
        std::string recovery_xpub;

        const uint32_t subaccount = m_next_subaccount;

        std::tie(pub_key, chain_code) = get_subaccount_master_xpub(m_master_key, subaccount);
        if (type == "2of3") {
            // The user can provide a recovery mnemonic or xpub; if not,
            // we generate and return a mnemonic for them.
            const auto user_recovery_xpub = json_get_value(details, "recovery_xpub");
            if (!user_recovery_xpub.empty()) {
                std::tie(recovery_pub_key, recovery_chain_code, recovery_xpub)
                    = get_recovery_key(user_recovery_xpub, subaccount);
            } else {
                const auto user_recovery_mnemonic = json_get_value(details, "recovery_mnemonic");
                if (user_recovery_mnemonic.empty()) {
                    recovery_mnemonic = generate_mnemonic();
                } else {
                    recovery_mnemonic = user_recovery_mnemonic; // User provided
                }
                std::tie(recovery_pub_key, recovery_chain_code, recovery_xpub)
                    = get_recovery_key(recovery_mnemonic, get_bip32_version(), subaccount);
            }
        }

        std::string receiving_id;
        wamp_call([&receiving_id](wamp_call_result result) { receiving_id = result.get().argument<std::string>(0); },
            "com.greenaddress.txs.create_subaccount", subaccount, name, pub_key, chain_code, recovery_pub_key,
            recovery_chain_code);

        ++m_next_subaccount;

        const bool has_txs = false;
        nlohmann::json subaccount_details
            = insert_subaccount(name, subaccount, receiving_id, recovery_pub_key, recovery_chain_code, type, has_txs);
        if (type == "2of3") {
            subaccount_details["recovery_mnemonic"] = recovery_mnemonic;
            subaccount_details["recovery_xpub"] = recovery_xpub;
        }
        return subaccount_details;
    } // namespace sdk

    wally_ext_key_ptr ga_session::get_recovery_extkey(uint32_t subaccount) const
    {
        using bytes = std::vector<unsigned char>;

        if (subaccount == 0)
            return wally_ext_key_ptr(); // Main account is always 2of2

        const nlohmann::json details = get_subaccount(subaccount);
        const std::string chain_code = details["recovery_chain_code"];
        const std::string pub_key = details["recovery_pub_key"];

        if (chain_code.empty() || pub_key.empty())
            return wally_ext_key_ptr();

        ext_key* p;
        uint32_t version = m_net_params.main_net() ? BIP32_VER_MAIN_PUBLIC : BIP32_VER_TEST_PUBLIC;
        bip32_key_init_alloc(
            version, 0, 0, bytes_from_hex(chain_code), bytes_from_hex(pub_key), bytes{}, bytes{}, bytes{}, &p);

        return wally_ext_key_ptr(p);
    }

    template <typename T>
    void ga_session::change_settings(const std::string& key, const T& value, const nlohmann::json& twofactor_data)
    {
        bool r{ false };
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.login.change_settings", key, value, as_messagepack(twofactor_data).get());
        GA_SDK_RUNTIME_ASSERT(r);
    }

    void ga_session::change_settings_tx_limits(bool is_fiat, uint32_t total, const nlohmann::json& twofactor_data)
    {
        // FIXME: move to use update_spending_limits
        const nlohmann::json args = { { "is_fiat", is_fiat }, { "per_tx", 0 }, { "total", total } };
        change_settings("tx_limits", as_messagepack(args).get(), twofactor_data);
    }

    void ga_session::change_settings_pricing_source(const std::string& currency, const std::string& exchange)
    {
        std::string fiat_rate;
        wamp_call(
            [&fiat_rate](boost::future<autobahn::wamp_call_result> result) {
                fiat_rate = result.get().argument<std::string>(0);
            },
            "com.greenaddress.login.set_pricing_source_v2", currency, exchange);
        // FIXME: Locking
        m_fiat_source = exchange;
        m_fiat_currency = currency;
        m_fiat_rate = fiat_rate;
    }

    nlohmann::json ga_session::get_transactions(uint32_t subaccount, uint32_t page_id)
    {
        nlohmann::json txs;
        wamp_call([&txs](wamp_call_result result) { txs = get_json_result(result.get()); },
            "com.greenaddress.txs.get_list_v2", page_id, std::string(), std::string(), std::string(), subaccount);

        // Update our local block height from the returned results
        // TODO: Use block_hash/height reversal to detect reorgs & uncache
        const uint32_t block_height = txs["cur_block"];
        GA_SDK_RUNTIME_ASSERT(block_height >= m_block_height);
        m_block_height = block_height;
        txs.erase("cur_block");
        txs.erase("block_hash");

        // Postprocess the returned API data
        // FIXME: confidential transactions, social payments/BIP70
        txs.erase("unclaimed"); // Always empty, never used
        txs.erase("fiat_currency");
        // Note: fiat_value is actually the fiat exchange rate
        if (!txs["fiat_value"].is_null()) {
            const double fiat_rate = txs["fiat_value"];
            m_fiat_rate = std::to_string(fiat_rate);
        }
        txs.erase("fiat_value");

        txs["page_id"] = page_id;
        json_add_if_missing(txs, "next_page_id", 0, true);

        for (auto& tx_details : txs["list"]) {
            const uint32_t tx_block_height = json_add_if_missing(tx_details, "block_height", 0, true);
            // TODO: Server should set subaccount to null if this is a spend from multiple subaccounts
            json_add_if_missing(tx_details, "has_payment_request", false);
            json_add_if_missing(tx_details, "memo", std::string());
            const std::string fee_str = tx_details["fee"];
            tx_details["fee"] = boost::lexical_cast<amount::value_type>(fee_str);
            const std::string tx_data = json_get_value(tx_details, "data");
            tx_details.erase("data");
            if (!tx_data.empty()) {
                // Only unconfirmed transactions are returned with the tx hex.
                // In this case update the size, weight etc.
                // At the moment to fetch the correct info for confirmed
                // transactions, callers must call get_transaction_details
                // on the hash of the confirmed transaction.
                // Once caching is implemented this info can be populated up
                // front so callers can always expect it.
                const auto tx = tx_from_hex(tx_data);
                update_tx_info(tx, tx_details);
            }

            amount received, spent;
            bool is_from_me = false; // Are any inputs from our wallet?
            std::map<uint32_t, nlohmann::json> in_map, out_map;

            // Clean up and categorize the endpoints
            for (auto& ep : tx_details["eps"]) {
                ep.erase("id");
                json_add_if_missing(ep, "subaccount", 0, true);
                json_rename_key(ep, "pubkey_pointer", "pointer");
                json_rename_key(ep, "ad", "address");
                json_add_if_missing(ep, "pointer", 0, true);
                json_add_if_missing(ep, "address", std::string(), true);
                const auto value = boost::lexical_cast<amount::value_type>(json_get_value(ep, "value"));
                ep["satoshi"] = value;
                ep.erase("value");

                if (ep.find("is_output") == ep.end()) {
                    // FIXME: not needed after next backend update
                    json_rename_key(ep, "is_credit", "is_output");
                } else {
                    ep.erase("is_credit");
                }

                const bool is_tx_output = ep.value("is_output", false);
                const bool is_relevant = ep.value("is_relevant", false);

                if (is_relevant) {
                    // Compute the effect of the input/output on the wallets balance
                    // TODO: Figure out what redeemable value for social payments is about
                    auto& which_balance = is_tx_output ? received : spent;
                    which_balance += value;
                    is_from_me |= !is_tx_output;
                }

                ep["addressee"] = std::string(); // default here, set below where needed

                // Note pt_idx on endpoints is the index within the tx, not the previous tx!
                const uint32_t pt_idx = ep["pt_idx"];
                auto& m = is_tx_output ? out_map : in_map;
                m.emplace(pt_idx, ep);
            }

            // Store the endpoints as inputs/outputs in tx index order
            nlohmann::json::array_t inputs, outputs;
            for (auto& it : in_map) {
                inputs.emplace_back(it.second);
            }
            tx_details["inputs"] = inputs;

            for (auto& it : out_map) {
                outputs.emplace_back(it.second);
            }
            tx_details["outputs"] = outputs;
            tx_details.erase("eps");

            // Compute tx economics and label addressees
            const bool net_positive = received > spent;
            const bool is_confirmed = tx_block_height != 0;
            std::vector<std::string> addressees;

            if (net_positive) {
                for (auto& ep : tx_details["inputs"]) {
                    std::string addressee;
                    if (!ep.value("is_relevant", false)) {
                        // Add unique addressees that aren't ourselves
                        addressee = json_get_value(ep, "social_source");
                        if (addressee.empty()) {
                            addressee = json_get_value(ep, "address");
                        }
                        if (std::find(std::begin(addressees), std::end(addressees), addressee)
                            == std::end(addressees)) {
                            addressees.emplace_back(addressee);
                        }
                        ep["addressee"] = addressee;
                    }
                }
                tx_details["type"] = "incoming";
                tx_details["can_rbf"] = false;
                tx_details["can_cpfp"] = !is_confirmed;
            } else {
                for (auto& ep : tx_details["outputs"]) {
                    std::string addressee;
                    if (!ep.value("is_relevant", false)) {
                        // Add unique addressees that aren't ourselves
                        const auto& social_destination = ep.find("social_destination");
                        if (social_destination != ep.end()) {
                            if (social_destination->is_object()) {
                                addressee = (*social_destination)["name"];
                            } else {
                                addressee = *social_destination;
                            }
                        } else {
                            addressee = ep["address"];
                        }

                        if (std::find(std::begin(addressees), std::end(addressees), addressee)
                            == std::end(addressees)) {
                            addressees.emplace_back(addressee);
                        }
                        ep["addressee"] = addressee;
                    }
                }
                tx_details["type"] = addressees.empty() ? "redeposit" : "outgoing";
                tx_details["can_rbf"] = !is_confirmed && tx_details.value("rbf_optin", false);
                tx_details["can_cpfp"] = false;
            }

            tx_details["addressees"] = addressees;

            const amount total = net_positive ? received - spent : spent - received;
            tx_details["satoshi"] = total.value();
            tx_details["user_signed"] = true;
            tx_details["server_signed"] = true;
        }
        return txs;
    }

    autobahn::wamp_subscription ga_session::subscribe(
        const std::string& topic, const autobahn::wamp_event_handler& callback)
    {
        autobahn::wamp_subscription sub;
        auto subscribe_future = m_session->subscribe(topic, callback, autobahn::wamp_subscribe_options("exact"))
                                    .then([&sub](boost::future<autobahn::wamp_subscription> subscription) {
                                        GDK_LOG_SEV(log_level::debug)
                                            << "subscribed to topic:" << subscription.get().id();
                                        sub = subscription.get();
                                    });

        subscribe_future.get();
        return sub;
    }

    autobahn::wamp_subscription ga_session::subscribe(
        const std::string& topic, const std::function<void(const std::string& output)>& callback)
    {
        return subscribe(topic, [callback](const autobahn::wamp_event& event) {
            const auto ev = event.argument<msgpack::object>(0);
            std::stringstream strm;
            strm << ev;
            callback(strm.str());
        });
    }

    amount ga_session::get_dust_threshold() const
    {
        const amount::value_type v = m_login_data["dust"];
        return amount(v);
    }

    std::vector<unsigned char> ga_session::output_script(uint32_t subaccount, const nlohmann::json& data) const
    {
        GA_SDK_RUNTIME_ASSERT(!is_watch_only());
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

        if (subaccount == 0) {
            return ga::sdk::output_script(m_net_params, m_master_key, wally_ext_key_ptr(), m_login_data["gait_path"],
                type, subtype, subaccount, pointer);
        } else {
            const auto subaccount_master_key = get_subaccount_master_key(m_master_key, subaccount);
            return ga::sdk::output_script(m_net_params, subaccount_master_key, get_recovery_extkey(subaccount),
                m_login_data["gait_path"], type, subtype, subaccount, pointer);
        }
    }

    nlohmann::json ga_session::get_unspent_outputs(uint32_t subaccount, uint32_t num_confs)
    {
        nlohmann::json utxos;
        wamp_call(
            [&utxos](wamp_call_result result) {
                const auto r = result.get();
                if (r.number_of_arguments()) {
                    utxos = get_json_result(r);
                }
            },
            "com.greenaddress.txs.get_all_unspent_outputs", num_confs, subaccount, "any");

        return cleanup_utxos(utxos);
    }

    nlohmann::json ga_session::get_unspent_outputs_for_private_key(
        const std::string& private_key, const std::string& password, uint32_t unused)
    {
        // Unused will be used in the future to support specifying the address type if
        // it can't be determined from the private_key format
        GA_SDK_RUNTIME_ASSERT(unused == 0);

        // FIXME: Issue 60:
        // Convert the private key string to a scriptpubkey, sha256 it into script_hash.
        // cleanup_utxos may need updating to handle the returned format and make it
        // consistent with get_unspent_outputs, the returned utxos should indicate if they
        // are from the wallet (from get_unspent_outputs()) or external (from here).
        // create_transaction should then be augmented so it can build a correct sweep tx
        // when given the resulting utxos.
        (void)private_key;
        (void)password;

        std::string script_hash = ""; // FIXME

        nlohmann::json utxos;
        wamp_call(
            [&utxos](wamp_call_result result) {
                const auto r = result.get();
                if (r.number_of_arguments()) {
                    utxos = get_json_result(r);
                }
            },
            "com.greenaddress.vault.get_utxos_for_script_hash", script_hash);
        return cleanup_utxos(utxos);
    }

    nlohmann::json ga_session::get_transaction_details(const std::string& txhash) const
    {
        std::string tx_data;
        wamp_call([&tx_data](wamp_call_result result) { tx_data = result.get().argument<std::string>(0); },
            "com.greenaddress.txs.get_raw_output", txhash);

        const auto tx = tx_from_hex(tx_data);
        nlohmann::json result = { { "txhash", txhash } };
        update_tx_info(tx, result);
        return result;
    }

    nlohmann::json ga_session::get_receive_address(uint32_t subaccount, const std::string& addr_type_) const
    {
        std::string addr_type = addr_type_.empty() ? get_default_address_type() : addr_type_;

        nlohmann::json address;
        wamp_call([&address](wamp_call_result result) { address = get_json_result(result.get()); },
            "com.greenaddress.vault.fund", subaccount, true, addr_type);

        const auto server_script = bytes_from_hex(address["script"]);
        const auto server_address = get_address_from_script(m_net_params, server_script, addr_type);

        if (!is_watch_only()) {
            // Compute the address locally to verify the servers data
            const auto user_script = output_script(subaccount, address);
            const auto user_address = get_address_from_script(m_net_params, user_script, addr_type);
            GA_SDK_RUNTIME_ASSERT(server_address == user_address);
        }

        address["address"] = server_address;
        return address;
    }

    nlohmann::json ga_session::get_balance(uint32_t subaccount, uint32_t num_confs)
    {
        nlohmann::json balance;
        wamp_call([&balance](wamp_call_result result) { balance = get_json_result(result.get()); },
            "com.greenaddress.txs.get_balance", subaccount, num_confs);
        // FIXME: Locking, Make sure another session didn't change fiat currency
        m_fiat_rate = balance["fiat_exchange"]; // Note: key name is wrong from the server!
        const std::string satoshi_str = json_get_value(balance, "satoshi");
        return amount::convert({ { "satoshi", strtoul(satoshi_str.c_str(), NULL, 10) } }, m_fiat_currency, m_fiat_rate);
    }

    nlohmann::json ga_session::get_available_currencies() const
    {
        nlohmann::json a;
        wamp_call([&a](wamp_call_result result) { a = get_json_result(result.get()); },
            "com.greenaddress.login.available_currencies");
        return a;
    }

    bool ga_session::is_rbf_enabled() const { return m_login_data["rbf"]; }

    bool ga_session::is_watch_only() const { return m_watch_only; }

    const std::string& ga_session::get_default_address_type() const
    {
        const auto& appearance = m_login_data["appearance"];
        if (appearance.value("use_csv", false))
            return address_type::csv;
        if (appearance.value("use_segwit", false))
            return address_type::p2wsh;
        return address_type::p2sh;
    }

    nlohmann::json ga_session::get_twofactor_config()
    {
        // FIXME: Locking
        if (m_twofactor_config.is_null()) {
            nlohmann::json f;
            wamp_call([&f](wamp_call_result result) { f = get_json_result(result.get()); },
                "com.greenaddress.twofactor.get_config");

            json_add_if_missing(f, "email_addr", std::string(), true);
            // FIXME: below line only needed until next testnet release
            json_add_if_missing(f, "phone_number", std::string());

            nlohmann::json email_config
                = { { "enabled", f["email"] }, { "confirmed", f["email_confirmed"] }, { "data", f["email_addr"] } };
            nlohmann::json sms_config
                = { { "enabled", f["sms"] }, { "confirmed", f["sms"] }, { "data", f["phone_number"] } };
            nlohmann::json phone_config
                = { { "enabled", f["phone"] }, { "confirmed", f["phone"] }, { "data", f["phone_number"] } };
            // Return the server generated gauth URL until gauth is enabled
            // (after being enabled, the server will no longer return it)
            const bool gauth_enabled = f["gauth"];
            std::string gauth_data = MASKED_GAUTH_SEED;
            if (!gauth_enabled) {
                gauth_data = f["gauth_url"];
            }
            nlohmann::json gauth_config
                = { { "enabled", gauth_enabled }, { "confirmed", gauth_enabled }, { "data", gauth_data } };

            nlohmann::json twofactor_config = {
                { "all_methods", ALL_2FA_METHODS },
                { "email", email_config },
                { "sms", sms_config },
                { "phone", phone_config },
                { "gauth", gauth_config },
            };
            set_enabled_twofactor_methods(twofactor_config);
            std::swap(m_twofactor_config, twofactor_config);
        }
        return m_twofactor_config;
    }

    void ga_session::set_enabled_twofactor_methods(nlohmann::json& config)
    {
        // FIXME: Locking
        std::vector<std::string> enabled_methods;
        enabled_methods.reserve(ALL_2FA_METHODS.size());
        for (const auto& m : ALL_2FA_METHODS) {
            if (config[m].value("enabled", false)) {
                enabled_methods.emplace_back(m);
            }
        }
        config["enabled_methods"] = enabled_methods;
        config["any_enabled"] = !enabled_methods.empty();
    }

    std::vector<std::string> ga_session::get_all_twofactor_methods()
    {
        // FIXME: Return from 2fa config when methods are returned from the server
        return ALL_2FA_METHODS;
    }

    std::vector<std::string> ga_session::get_enabled_twofactor_methods()
    {
        return get_twofactor_config()["enabled_methods"];
    }

    void ga_session::set_email(const std::string& email, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(!m_twofactor_config.is_null()); // Caller must fetch before changing

        wamp_call([](wamp_call_result result) { result.get(); }, "com.greenaddress.twofactor.set_email", email,
            as_messagepack(twofactor_data).get());
        // FIXME: locking, update data only after activate?
        m_twofactor_config["email"]["data"] = email;
    }

    void ga_session::activate_email(const std::string& code)
    {
        GA_SDK_RUNTIME_ASSERT(!m_twofactor_config.is_null()); // Caller must fetch before changing

        wamp_call([](wamp_call_result result) { result.get(); }, "com.greenaddress.twofactor.activate_email", code);
        // FIXME: locking
        m_twofactor_config["email"]["confirmed"] = true;
    }

    void ga_session::init_enable_twofactor(
        const std::string& method, const std::string& data, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(!m_twofactor_config.is_null()); // Caller must fetch before changing

        const std::string api_method = "com.greenaddress.twofactor.init_enable_" + method;
        wamp_call(
            [](wamp_call_result result) { result.get(); }, api_method, data, as_messagepack(twofactor_data).get());
        m_twofactor_config[method]["data"] = data;
    }

    void ga_session::enable_twofactor(const std::string& method, const std::string& code)
    {
        GA_SDK_RUNTIME_ASSERT(!m_twofactor_config.is_null()); // Caller must fetch before changing

        std::string api_method = "com.greenaddress.twofactor.enable_" + method;
        wamp_call([](wamp_call_result result) { result.get(); }, api_method, code);

        // Update our local 2fa config FIXME: locking
        const std::string masked; // FIXME: Use a real masked value
        m_twofactor_config[method] = { { "enabled", true }, { "confirmed", true }, { "data", masked } };
        set_enabled_twofactor_methods(m_twofactor_config);
    }

    void ga_session::enable_gauth(const std::string& code, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(!m_twofactor_config.is_null()); // Caller must fetch before changing

        wamp_call([](wamp_call_result result) { result.get(); }, "com.greenaddress.twofactor.enable_gauth", code,
            as_messagepack(twofactor_data).get());
        // Update our local 2fa config FIXME: locking
        m_twofactor_config["gauth"] = { { "enabled", true }, { "confirmed", true }, { "data", MASKED_GAUTH_SEED } };
        set_enabled_twofactor_methods(m_twofactor_config);
    }

    void ga_session::disable_twofactor(const std::string& method, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(!m_twofactor_config.is_null()); // Caller must fetch before changing

        const std::string api_method = "com.greenaddress.twofactor.disable_" + method;
        wamp_call([](wamp_call_result result) { result.get(); }, api_method, as_messagepack(twofactor_data).get());
        // If the call succeeds it means the method was previously enabled, hence
        // for email the email address is still confirmed even though 2fa is disabled.
        const bool confirmed = method == "email";

        // Update our local 2fa config FIXME: locking
        const std::string masked
            = method == "gauth" ? MASKED_GAUTH_SEED : std::string(); // FIXME: Use a real masked value
        m_twofactor_config[method] = { { "enabled", false }, { "confirmed", confirmed }, { "data", masked } };
        set_enabled_twofactor_methods(m_twofactor_config);
    }

    void ga_session::twofactor_request_code(
        const std::string& method, const std::string& action, const nlohmann::json& twofactor_data)
    {
        const std::string api_method = "com.greenaddress.twofactor.request_" + method;
        wamp_call(
            [](wamp_call_result result) { result.get(); }, api_method, action, as_messagepack(twofactor_data).get());
    }

    nlohmann::json ga_session::set_pin(const std::string& mnemonic, const std::string& pin, const std::string& device)
    {
        bip39_mnemonic_validate(nullptr, mnemonic);

        GA_SDK_RUNTIME_ASSERT(pin.length() >= 4);
        GA_SDK_RUNTIME_ASSERT(!device.empty() && device.length() <= 100);

        // Ask the server to create a new PIN identifier and PIN password
        std::string pin_identifier;
        wamp_call(
            [&pin_identifier](wamp_call_result result) { pin_identifier = result.get().argument<std::string>(0); },
            "com.greenaddress.pin.set_pin_login", pin, device);

        // FIXME: secure_array
        std::array<unsigned char, BIP39_SEED_LEN_512> seed;
        GA_SDK_RUNTIME_ASSERT(bip39_mnemonic_to_seed(mnemonic, nullptr, seed) == seed.size());
        // const auto mnemonic_bytes = mnemonic_to_bytes(mnemonic);

        // TODO: Get password from pin.set_pin_login when server is updated
        const auto password = get_pin_password(pin, pin_identifier);

        // Encrypt the users mnemonic and seed using a key dervied from the
        // PIN password and a randomly generated salt.
        // Note the use of base64 here is to remain binary compatible with
        // old GreenBits installs.
        const auto salt = get_random_bytes<16>();
        const auto salt_b64 = websocketpp::base64_encode(salt.data(), salt.size());
        std::array<unsigned char, PBKDF2_HMAC_SHA256_LEN> key;
        get_pin_key(password, salt_b64, key);

        // FIXME: secure_array
        const auto iv = get_random_bytes<AES_BLOCK_LEN>();
        // FIXME: secure string
        const std::string json = nlohmann::json({ { "mnemonic", mnemonic }, { "seed", hex_from_bytes(seed) } }).dump();
        const auto plaintext = gsl::make_span(reinterpret_cast<const unsigned char*>(json.data()), json.size());

        const size_t plaintext_padded_size = (json.size() / AES_BLOCK_LEN + 1) * AES_BLOCK_LEN;
        std::vector<unsigned char> encrypted(iv.size() + plaintext_padded_size);
        auto ciphertext = gsl::make_span(encrypted.data() + iv.size(), plaintext_padded_size);
        const auto written = aes_cbc(key, iv, plaintext, AES_FLAG_ENCRYPT, ciphertext);
        GA_SDK_RUNTIME_ASSERT(written == static_cast<size_t>(ciphertext.size()));
        std::copy(iv.begin(), iv.end(), encrypted.begin());

        return { { "pin_identifier", pin_identifier }, { "salt", salt_b64 },
            { "encrypted_data", hex_from_bytes(encrypted) } };
    }

    std::vector<unsigned char> ga_session::get_pin_password(const std::string& pin, const std::string& pin_identifier)
    {
        std::string password;
        std::string error;
        wamp_call(
            [&password, &error](wamp_call_result result) {
                try {
                    password = result.get().argument<std::string>(0);
                } catch (const std::exception& e) {
                    error = e.what();
                }
            },
            "com.greenaddress.pin.get_password", pin, pin_identifier);

        if (!error.empty()) {
            throw login_error(error);
        }

        return std::vector<unsigned char>(password.begin(), password.end());
    }

    void ga_session::sign_input(const wally_tx_ptr& tx, uint32_t index, const nlohmann::json& u) const
    {
        const auto txhash = u["txhash"];
        const uint32_t subaccount = u.value("subaccount", 0);
        const uint32_t pointer = u["pointer"];
        const amount::value_type v = u["satoshi"]; // FIXME: Allow amount conversions directly
        const amount satoshi{ v };
        const auto type = script_type(u["script_type"]);

        const auto prevout_script = output_script(subaccount, u);

        std::array<unsigned char, SHA256_LEN> tx_hash;
        const uint32_t flags = is_segwit_script_type(type) ? WALLY_TX_FLAG_USE_WITNESS : 0;
        tx_get_btc_signature_hash(tx, index, prevout_script, satoshi.value(), WALLY_SIGHASH_ALL, flags, tx_hash);

        // FIXME: secure_array
        std::array<unsigned char, EC_PRIVATE_KEY_LEN> client_priv_key;
        derive_private_key(m_master_key, std::array<uint32_t, 2>{ { 1, pointer } }, client_priv_key);

        std::array<unsigned char, EC_SIGNATURE_LEN> user_sig;
        ec_sig_from_bytes(client_priv_key, tx_hash, EC_FLAG_ECDSA | EC_FLAG_GRIND_R, user_sig);

        if (is_segwit_script_type(type)) {
            // TODO: If the UTXO is CSV and expired, spend it using the users key only (smaller)
            // Note that this requires setting the inputs sequence number to the CSV time too
            auto wit = tx_witness_stack_init(1);
            tx_witness_stack_add(wit, ec_sig_to_der(user_sig, true));
            tx_set_input_witness(tx, index, wit);
            tx_set_input_script(tx, index, witness_script(prevout_script));
        } else {
            tx_set_input_script(tx, index, input_script(prevout_script, user_sig));
        }
    }

    nlohmann::json ga_session::send_transaction(const nlohmann::json& details, const nlohmann::json& twofactor_data)
    {
        nlohmann::json result = details;

        // We must have a tx and it must be signed by the user
        GA_SDK_RUNTIME_ASSERT(result.find("transaction") != result.end());
        GA_SDK_RUNTIME_ASSERT(result.value("user_signed", false));

        // FIXME: test weight and return error in create_transaction, not here
        const std::string tx_hex = result.at("transaction");
        const size_t MAX_TX_WEIGHT = 400000;
        const auto unsigned_tx = tx_from_hex(tx_hex);
        GA_SDK_RUNTIME_ASSERT(tx_get_weight(unsigned_tx) < MAX_TX_WEIGHT);

        nlohmann::json private_data;
        const std::string memo = json_get_value(result, "memo");
        if (!memo.empty()) {
            private_data["memo"] = memo;
        }
        // FIXME: social_destination/social_destination_type/payreq if BIP70

        const bool return_tx = true;
        nlohmann::json tx_details;
        wamp_call([&tx_details](wamp_call_result result) { tx_details = get_json_result(result.get()); },
            "com.greenaddress.vault.send_raw_tx", tx_hex, as_messagepack(twofactor_data).get(),
            as_messagepack(private_data).get(), return_tx);

        update_spending_limits(tx_details["limits"]);

        // Update the details with the server signed transaction, since it
        // may be a slightly different size once signed
        result["txhash"] = tx_details["txhash"];
        const auto tx = tx_from_hex(tx_details["tx"]);
        update_tx_info(tx, result);
        result["server_signed"] = true;
        return result;
    }

    void ga_session::send_nlocktimes()
    {
        bool r;
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.login.send_nlocktime");
        GA_SDK_RUNTIME_ASSERT(r);
    }

    void ga_session::set_transaction_memo(
        const std::string& txhash_hex, const std::string& memo, const std::string& memo_type)
    {
        wamp_call([](boost::future<autobahn::wamp_call_result> result) { result.get(); },
            "com.greenaddress.txs.change_memo", txhash_hex, memo, memo_type);
    }

} // namespace sdk
} // namespace ga
