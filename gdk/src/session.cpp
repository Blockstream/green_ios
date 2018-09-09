#include <algorithm>
#include <array>
#include <ctime>
#include <map>
#include <queue>
#include <string>
#include <thread>
#include <type_traits>
#include <vector>

#include <gsl/span>

#include "boost_wrapper.hpp"
#include <boost/beast/core/detail/base64.hpp>

#include "assertion.hpp"
#include "autobahn_wrapper.hpp"
#include "exception.hpp"
#include "memory.hpp"
#include "session.hpp"
#include "transaction_utils.hpp"

namespace ga {
namespace sdk {
#ifdef NDEBUG
    using websocketpp_gdk_config = websocketpp::config::asio_client;
    using websocketpp_gdk_tls_config = websocketpp::config::asio_tls_client;
#else
    struct websocketpp_gdk_config : public websocketpp::config::asio_client {
        static const websocketpp::log::level alog_level = websocketpp::log::alevel::devel;
    };

    struct websocketpp_gdk_tls_config : public websocketpp::config::asio_tls_client {
        static const websocketpp::log::level alog_level = websocketpp::log::alevel::devel;
    };
#endif

    using client = websocketpp::client<websocketpp_gdk_config>;
    using client_tls = websocketpp::client<websocketpp_gdk_tls_config>;
    using transport = autobahn::wamp_websocketpp_websocket_transport<websocketpp_gdk_config>;
    using transport_tls = autobahn::wamp_websocketpp_websocket_transport<websocketpp_gdk_tls_config>;
    using context_ptr = websocketpp::lib::shared_ptr<boost::asio::ssl::context>;
    using wamp_call_result = boost::future<autobahn::wamp_call_result>;
    using wamp_session_ptr = std::shared_ptr<autobahn::wamp_session>;

    static const std::string DEFAULT_REALM("realm1");
    static const std::string DEFAULT_USER_AGENT("[v2,sw,csv]");
    static const unsigned char GA_LOGIN_NONCE[30] = { 'G', 'r', 'e', 'e', 'n', 'A', 'd', 'd', 'r', 'e', 's', 's', '.',
        'i', 't', ' ', 'H', 'D', ' ', 'w', 'a', 'l', 'l', 'e', 't', ' ', 'p', 'a', 't', 'h' };

    // Dummy data for transaction creation with correctly sized data for fee estimation
    static const std::vector<unsigned char> DUMMY_WITNESS_SCRIPT(3 + SHA256_LEN);

    namespace {
        const uint32_t DEFAULT_MIN_FEE = 1000; // 1 satoshi/byte
        const uint32_t NUM_FEE_ESTIMATES = 24;

        std::once_flag one_time_setup_flag;

        void one_time_setup()
        {
            std::call_once(one_time_setup_flag, [] {
                wally::init(0);
                wally::secp_randomize(get_random_bytes<WALLY_SECP_RANDOMISE_LEN>());
            });
        }

        // FIXME: too slow. lacks validation.
        std::array<unsigned char, 32> uint256_to_base256(const std::string& input)
        {
            constexpr size_t base = 256;

            std::array<unsigned char, 32> repr;
            size_t i = repr.size() - 1;
            for (boost::multiprecision::checked_uint256_t num(input); num; num = num / base, --i) {
                repr[i] = static_cast<unsigned char>(num % base);
            }

            return repr;
        }

        void get_pin_key(const std::vector<unsigned char>& password, const std::string& salt,
            std::array<unsigned char, PBKDF2_HMAC_SHA256_LEN>& out)
        {
            const auto salt_bytes = gsl::make_span(reinterpret_cast<const unsigned char*>(salt.data()), salt.size());
            pbkdf2_hmac_sha512_256(password, salt_bytes, 0, 2048, out);
        }

        template <typename T> nlohmann::json get_json_result(const T& result)
        {
            auto obj = result.template argument<msgpack::object>(0);
            std::stringstream ss;
            ss << obj;
            return nlohmann::json::parse(ss.str());
        }

        nlohmann::json get_fees_as_json(const autobahn::wamp_event& event)
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

        msgpack::object_handle as_messagepack(const nlohmann::json& json)
        {
            const auto buffer = nlohmann::json::to_msgpack(json);
            return msgpack::unpack(reinterpret_cast<const char*>(buffer.data()), buffer.size());
        }
    } // namespace

    struct event_loop_controller {
        explicit event_loop_controller(boost::asio::io_service& io)
            : m_work_guard(std::make_unique<boost::asio::io_service::work>(io))
        {
            m_run_thread = std::thread([&] { io.run(); });
        }

        ~event_loop_controller()
        {
            m_work_guard.reset();
            m_run_thread.join();
        }

        std::thread m_run_thread;
        std::unique_ptr<boost::asio::io_service::work> m_work_guard;
    };

    class session::session_impl final {
    public:
        session_impl(network_parameters net_params, bool debug)
            : m_controller(m_io)
            , m_net_params(std::move(net_params))
            , m_min_fee(DEFAULT_MIN_FEE)
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
            m_fee_estimates.assign(NUM_FEE_ESTIMATES, m_min_fee);
            connect_with_tls() ? make_client<client_tls>() : make_client<client>();
        }

        session_impl(const session_impl& other) = delete;
        session_impl(session_impl&& other) noexcept = delete;
        session_impl& operator=(const session_impl& other) = delete;
        session_impl& operator=(session_impl&& other) noexcept = delete;

        ~session_impl()
        {
            disconnect();
            m_io.stop();
        }

        void connect();
        void disconnect();
        void register_user(const std::string& mnemonic, const std::string& user_agent);
        void login(const std::string& mnemonic, const std::string& user_agent);
        void login(
            const std::string& pin, const nlohmann::json& pin_data, const std::string& user_agent = std::string());
        void login_watch_only(const std::string& username, const std::string& password, const std::string& user_agent);
        bool set_watch_only(const std::string& username, const std::string& password);
        bool remove_account(const nlohmann::json& twofactor_data);

        wally_ext_key_ptr get_recovery_extkey(uint32_t subaccount) const;

        template <typename T>
        void change_settings(const std::string& key, const T& value, const nlohmann::json& twofactor_data);
        void change_settings_tx_limits(
            bool is_fiat, uint32_t per_tx, uint32_t total, const nlohmann::json& twofactor_data);

        nlohmann::json get_transactions(uint32_t subaccount, uint32_t page_id);
        void subscribe(const std::string& topic, const autobahn::wamp_event_handler& callback);
        void subscribe(const std::string& topic, std::function<void(const std::string& output)> callback);
        nlohmann::json get_subaccounts() const;
        nlohmann::json get_subaccount(uint32_t subaccount) const;
        nlohmann::json create_subaccount(const nlohmann::json& details);
        nlohmann::json get_receive_address(uint32_t subaccount, address_type addr_type) const;
        template <typename T> nlohmann::json get_balance(T subaccount, uint32_t num_confs) const;
        nlohmann::json get_available_currencies() const;
        bool is_rbf_enabled() const;
        bool is_watch_only() const;
        address_type get_default_address_type() const;

        nlohmann::json get_twofactor_config();

        void set_email(const std::string& email, const nlohmann::json& twofactor_data);
        void activate_email(const std::string& code);
        void init_enable_twofactor(
            const std::string& method, const std::string& data, const nlohmann::json& twofactor_data);
        void enable_twofactor(const std::string& method, const std::string& code);
        void enable_gauth(const std::string& code, const nlohmann::json& twofactor_data);
        void disable_twofactor(const std::string& method, const nlohmann::json& twofactor_data);

        void twofactor_request_code(const std::string& method, const std::string& action, const nlohmann::json& data);

        nlohmann::json set_pin(const std::string& mnemonic, const std::string& pin, const std::string& device);

        bool add_address_book_entry(const std::string& address, const std::string& name);
        bool edit_address_book_entry(const std::string& address, const std::string& name);
        void delete_address_book_entry(const std::string& address);

        template <typename T> nlohmann::json get_unspent_outputs(T subaccount, uint32_t num_confs);
        nlohmann::json get_transaction_details(const std::string& txhash) const;

        std::string make_raw_tx(const std::vector<std::pair<std::string, amount>>& address_amount,
            const nlohmann::json& utxos, amount fee_rate, bool send_all);
        nlohmann::json send(const std::string& tx_hex, const nlohmann::json& twofactor_data);
        nlohmann::json send(const std::vector<std::pair<std::string, amount>>& address_amount,
            const nlohmann::json& utxos, amount fee_rate, bool send_all, const nlohmann::json& twofactor_data);

        template <typename T>
        nlohmann::json send(T subaccount, const std::vector<std::pair<std::string, amount>>& address_amount,
            amount fee_rate, bool send_all, const nlohmann::json& twofactor_data);

        void send_nlocktimes();

        void set_transaction_memo(const std::string& txhash_hex, const std::string& memo, const std::string& memo_type);

        void change_settings_pricing_source(const std::string& currency, const std::string& exchange);

        nlohmann::json get_fee_estimates();

        std::string get_mnemonic_passphrase(const std::string& password);

        std::string get_system_message();
        void ack_system_message(const std::string& system_message);

    private:
        void set_login_data(nlohmann::json&& login_data, bool watch_only);
        void on_new_transaction(const nlohmann::json& details);

        nlohmann::json insert_subaccount(const std::string& name, uint32_t pointer, const std::string& receiving_id,
            const std::string& recovery_pub_key, const std::string& recovery_chain_code, const std::string& type,
            bool has_txs);

        template <typename PathT>
        static std::string sign_hash(
            const wally_ext_key_ptr& master_key, const PathT& path, const std::array<unsigned char, 32>& hash)
        {
            // FIXME: secure_array
            std::array<unsigned char, EC_PRIVATE_KEY_LEN> login_priv_key;
            derive_private_key(master_key, path, login_priv_key);

            std::array<unsigned char, EC_SIGNATURE_LEN> sig;
            ec_sig_from_bytes(login_priv_key, hash, EC_FLAG_ECDSA | EC_FLAG_GRIND_R, sig);

            return hex_from_bytes(ec_sig_to_der(sig));
        }

        static std::pair<std::string, std::string> sign_challenge(
            const wally_ext_key_ptr& master_key, const std::string& challenge);

        void set_fee_estimates(const nlohmann::json& fee_estimates);

        bool connect_with_tls() const
        {
            return boost::algorithm::starts_with(
                !m_net_params.get_use_tor() ? m_net_params.gait_wamp_url() : m_net_params.gait_onion(), "wss://");
        }

        template <typename T> std::enable_if_t<std::is_same<T, client>::value> set_tls_init_handler() {}
        template <typename T> std::enable_if_t<std::is_same<T, client_tls>::value> set_tls_init_handler()
        {
            m_cert_pin_validated = false;
            boost::get<std::unique_ptr<T>>(m_client)->set_tls_init_handler([this](const websocketpp::connection_hdl) {
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
            });
        }

        template <typename T> void make_client()
        {
            m_client = std::make_unique<T>();
            boost::get<std::unique_ptr<T>>(m_client)->init_asio(&m_io);
            set_tls_init_handler<T>();
        }

        template <typename T> void make_transport()
        {
            using client_type
                = std::unique_ptr<std::conditional_t<std::is_same<T, transport_tls>::value, client_tls, client>>;

            m_transport = std::make_shared<T>(*boost::get<client_type>(m_client),
                !m_net_params.get_use_tor() ? m_net_params.gait_wamp_url() : m_net_params.gait_onion(),
                m_net_params.get_proxy(), m_debug);
            boost::get<std::shared_ptr<T>>(m_transport)
                ->attach(std::static_pointer_cast<autobahn::wamp_transport_handler>(m_session));
        }

        template <typename T> void connect_to_endpoint() const
        {
            std::array<boost::future<void>, 3> futures;

            futures[0]
                = boost::get<std::shared_ptr<T>>(m_transport)->connect().then([&](boost::future<void> connected) {
                      connected.get();
                      futures[1] = m_session->start().then([&](boost::future<void> started) {
                          started.get();
                          futures[2] = m_session->join(DEFAULT_REALM).then([&](boost::future<uint64_t> joined) {
                              joined.get();
                          });
                      });
                  });

            for (auto&& f : futures) {
                f.get();
            }
        }

        template <typename F, typename... Args>
        void wamp_call(F&& body, const std::string& method_name, Args&&... args) const
        {
            constexpr uint8_t timeout = 10;
            autobahn::wamp_call_options call_options;
            call_options.set_timeout(std::chrono::seconds(timeout));
            auto fn = m_session->call(method_name, std::make_tuple(std::forward<Args>(args)...), call_options)
                          .then(std::forward<F>(body));
            const auto status = fn.wait_for(boost::chrono::seconds(timeout));
            fn.get();

            if (status == boost::future_status::timeout) {
                throw timeout_error{};
            }
            GA_SDK_RUNTIME_ASSERT(status == boost::future_status::ready);
        }

        std::vector<unsigned char> get_pin_password(const std::string& pin, const std::string& pin_identifier);

        amount get_dust_threshold() const;

        std::vector<unsigned char> output_script(uint32_t subaccount, const nlohmann::json& data) const;
        amount add_utxo(const wally_tx_ptr& tx, const nlohmann::json& u) const;
        void sign_input(const wally_tx_ptr& tx, uint32_t index, const nlohmann::json& u) const;

        amount get_tx_fee(const wally_tx_ptr& tx, amount fee_rate);

        uint32_t get_bip32_version() const
        {
            return m_net_params.main_net() ? BIP32_VER_MAIN_PRIVATE : BIP32_VER_TEST_PRIVATE;
        }

        boost::asio::io_service m_io;
        boost::variant<std::unique_ptr<client>, std::unique_ptr<client_tls>> m_client;
        boost::variant<std::shared_ptr<transport>, std::shared_ptr<transport_tls>> m_transport;
        wamp_session_ptr m_session;

        event_loop_controller m_controller;

        network_parameters m_net_params;

        nlohmann::json m_login_data;
        std::string m_mnemonic;
        amount::value_type m_min_fee;
        std::map<uint32_t, nlohmann::json> m_subaccounts; // Includes 0 for main
        uint32_t m_next_subaccount;
        std::vector<uint32_t> m_fee_estimates;
        std::atomic<uint32_t> m_block_height;
        wally_ext_key_ptr m_master_key;

        uint32_t m_system_message_id; // Next system message
        uint32_t m_system_message_ack_id; // Currently returned message id to ack
        std::string m_system_message_ack; // Currently returned message to ack
        bool m_watch_only;
        const boost::asio::ssl::rfc2818_verification m_rfc2818_verifier;
        bool m_cert_pin_validated;
        bool m_debug;
    };

    void session::session_impl::connect()
    {
        m_session = std::make_shared<autobahn::wamp_session>(m_io, m_debug);

        const bool tls = connect_with_tls();
        tls ? make_transport<transport_tls>() : make_transport<transport>();
        tls ? connect_to_endpoint<transport_tls>() : connect_to_endpoint<transport>();
    }

    void session::session_impl::disconnect()
    {
        m_mnemonic.clear(); // FIXME: securely clear
        // FIXME: unsubscribe/kill WAMP connection
        // FIXME: securely destroy all held data
    }

    std::pair<std::string, std::string> session::session_impl::sign_challenge(
        const wally_ext_key_ptr& master_key, const std::string& challenge)
    {
        auto path_bytes = get_random_bytes<8>();

        std::array<uint32_t, 4> path;
        adjacent_transform(std::begin(path_bytes), std::end(path_bytes), std::begin(path),
            [](auto first, auto second) { return uint32_t((first << 8) + second); });

        const auto challenge_hash = uint256_to_base256(challenge);

        return { sign_hash(master_key, path, challenge_hash), hex_from_bytes(path_bytes) };
    }

    void session::session_impl::set_fee_estimates(const nlohmann::json& fee_estimates)
    {
        // Convert server estimates into an array of NUM_FEE_ESTIMATES estimates ordered by block
        std::vector<uint32_t> new_estimates(NUM_FEE_ESTIMATES);
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
                if (actual_block > 0 && actual_block <= new_estimates.size()) {
                    const long long satoshi_per_k = std::lround(btc_per_k * amount::coin_value);
                    const long long uint32_t_max = std::numeric_limits<uint32_t>::max();
                    if (satoshi_per_k >= DEFAULT_MIN_FEE && satoshi_per_k <= uint32_t_max) {
                        ordered_estimates[actual_block] = static_cast<uint32_t>(satoshi_per_k);
                    }
                }
            }
        }
        size_t i = 0;
        for (const auto& e : ordered_estimates) {
            while (i < e.first) {
                new_estimates[i] = e.second;
                ++i;
            }
        }

        // FIXME locking for m_fee_estimates
        if (i) {
            while (i < new_estimates.size()) {
                new_estimates[i] = new_estimates[i - 1];
                ++i;
            }
        } else {
            // No usable estimates, use existing ones until new ones arrive
            return;
        }

        std::swap(m_fee_estimates, new_estimates);
    }

    void session::session_impl::register_user(const std::string& mnemonic, const std::string& user_agent)
    {
        // Only the English word list is supported. This check is important because bip39_mnemonic_to_seed
        // does not do any validation (by design)
        mnemonic_validate("en", mnemonic);

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

    void session::session_impl::set_login_data(nlohmann::json&& login_data, bool watch_only)
    {
        m_login_data = login_data;

        const uint32_t min_fee = m_login_data["min_fee"];
        if (min_fee != m_min_fee) {
            m_min_fee = min_fee;
            m_fee_estimates.assign(NUM_FEE_ESTIMATES, m_min_fee);
        }

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
    }

    void session::session_impl::on_new_transaction(const nlohmann::json& details)
    {
        // FIXME: Update have_transactions in each affected subaccount,
        // mark cached tx lists (when implemented) as dirty, and notify the user
        (void)details;
    }

    void session::session_impl::login(const std::string& mnemonic, const std::string& user_agent)
    {
        mnemonic_validate("en", mnemonic);

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
        wamp_call([this](wamp_call_result result) { set_login_data(get_json_result(result.get()), false); },
            "com.greenaddress.login.authenticate", hexder_path.first, false, hexder_path.second,
            std::string("fake_dev_id"), DEFAULT_USER_AGENT + user_agent + "_ga_sdk");

        m_mnemonic = mnemonic;

        const std::string receiving_id = m_login_data["receiving_id"];
        subscribe("com.greenaddress.txs.wallet_" + receiving_id,
            [this](const autobahn::wamp_event& event) { on_new_transaction(get_json_result(event)); });

        subscribe("com.greenaddress.blocks", [this](const autobahn::wamp_event& event) {
            const nlohmann::json block_ev = get_json_result(event);
            const uint32_t block_height = block_ev["count"];
            GA_SDK_RUNTIME_ASSERT(block_height >= m_block_height);
            m_block_height = block_height;
        });

        subscribe("com.greenaddress.fee_estimates",
            [this](const autobahn::wamp_event& event) { set_fee_estimates(get_fees_as_json(event)); });

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

    void session::session_impl::login(
        const std::string& pin, const nlohmann::json& pin_data, const std::string& user_agent)
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

    void session::session_impl::login_watch_only(
        const std::string& username, const std::string& password, const std::string& user_agent)
    {
        const std::map<std::string, std::string> args = { { "username", username }, { "password", password } };
        wamp_call([this](wamp_call_result result) { set_login_data(get_json_result(result.get()), true); },
            "com.greenaddress.login.watch_only_v2", "custom", args, DEFAULT_USER_AGENT + user_agent + "_ga_sdk");
    }

    nlohmann::json session::session_impl::get_fee_estimates()
    {
        // FIXME: locking, augment with last_updated, user preference for display?
        return { { "estimates", m_fee_estimates } };
    }

    std::string session::session_impl::get_mnemonic_passphrase(const std::string& password)
    {
        GA_SDK_RUNTIME_ASSERT(!is_watch_only());
        GA_SDK_RUNTIME_ASSERT(password.empty()); // FIXME: Implement encryption
        GA_SDK_RUNTIME_ASSERT(!m_mnemonic.empty());
        return m_mnemonic;
    }

    std::string session::session_impl::get_system_message()
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

    void session::session_impl::ack_system_message(const std::string& message)
    {
        GA_SDK_RUNTIME_ASSERT(!message.empty() && message == m_system_message_ack);

        std::array<unsigned char, SHA256_LEN> message_hash;
        sha256d(std::vector<unsigned char>(message.begin(), message.end()), message_hash);

        const auto message_hash_hex = hex_from_bytes(message_hash);
        const auto ls_uint32_hex = message_hash_hex.substr(message_hash_hex.length() - 8);
        const uint32_t ls_uint32 = std::stoul(ls_uint32_hex, 0, 16);
        static const auto unharden = ~(0x01 << 31);
        std::array<uint32_t, 3> path = { { 0x4741b11e, 6, ls_uint32 & unharden } };

        std::vector<unsigned char> message_hex_bytes(message_hash_hex.begin(), message_hash_hex.end());
        std::array<unsigned char, SHA256_LEN> hash;
        const size_t written = format_bitcoin_message(message_hex_bytes, BITCOIN_MESSAGE_FLAG_HASH, hash);
        GA_SDK_RUNTIME_ASSERT(written == hash.size());
        const auto signature = sign_hash(m_master_key, path, hash);

        wamp_call([](wamp_call_result result) { GA_SDK_RUNTIME_ASSERT(result.get().argument<bool>(0)); },
            "com.greenaddress.login.ack_system_message", m_system_message_ack_id, message_hash_hex, signature);
        m_system_message_ack = std::string();
    }

    bool session::session_impl::set_watch_only(const std::string& username, const std::string& password)
    {
        bool r;
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.addressbook.sync_custom", username, password);
        return r;
    }

    bool session::session_impl::remove_account(const nlohmann::json& twofactor_data)
    {
        bool r;
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.login.remove_account", as_messagepack(twofactor_data).get());
        return r;
    }

    namespace {
        auto get_hdkey(const wally_ext_key_ptr& key, uint32_t pointer, bool skip_hash = true)
        {
            const auto subkey = derive_key(key,
                std::array<uint32_t, 2>{ { BIP32_INITIAL_HARDENED_CHILD | 3, BIP32_INITIAL_HARDENED_CHILD | pointer } },
                false, skip_hash);
            return std::make_pair(
                hex_from_bytes(gsl::make_span(subkey->pub_key)), hex_from_bytes(gsl::make_span(subkey->chain_code)));
        }

        auto get_recovery_key(const wally_ext_key_ptr& hdkey, const std::string& xpub, uint32_t pointer)
        {
            std::string pub_key, chain_code;
            std::tie(pub_key, chain_code) = get_hdkey(hdkey, pointer, false);
            return std::make_tuple(pub_key, chain_code, xpub);
        }

        auto get_recovery_key(const std::string& mnemonic, uint32_t bip32_version, uint32_t pointer)
        {
            mnemonic_validate("en", mnemonic);

            // FIXME: secure_array
            std::array<unsigned char, BIP39_SEED_LEN_512> seed;
            GA_SDK_RUNTIME_ASSERT(bip39_mnemonic_to_seed(mnemonic, nullptr, seed) == seed.size());

            ext_key* p;
            bip32_key_from_seed_alloc(seed, bip32_version, BIP32_FLAG_SKIP_HASH, &p);
            wally_ext_key_ptr hdkey(p);
            std::array<unsigned char, BIP32_SERIALIZED_LEN> xpub_bytes;
            bip32_key_serialize(hdkey, BIP32_FLAG_KEY_PUBLIC, xpub_bytes);
            return get_recovery_key(hdkey, base58check_from_bytes(xpub_bytes), pointer);
        }

        auto get_recovery_key(const std::string& xpub, uint32_t pointer)
        {
            std::array<unsigned char, BIP32_SERIALIZED_LEN + BASE58_CHECKSUM_LEN> xpub_bytes;
            GA_SDK_RUNTIME_ASSERT(base58check_to_bytes(xpub, xpub_bytes) == BIP32_SERIALIZED_LEN);

            ext_key* p;
            bip32_key_unserialize_alloc(gsl::make_span(xpub_bytes.data(), BIP32_SERIALIZED_LEN), &p);
            return get_recovery_key(wally_ext_key_ptr(p), xpub, pointer);
        }

        std::string get_address_type_string(address_type addr_type)
        {
            switch (addr_type) {
            case address_type::p2sh:
                return "p2sh";
            case address_type::p2wsh:
                return "p2wsh";
            case address_type::csv:
                return "csv";
            }
            __builtin_unreachable();
        }

        std::string get_address_from_script(const std::vector<unsigned char>& script, address_type addr_type)
        {
            switch (addr_type) {
            case address_type::p2sh:
                return base58check_from_bytes(p2sh_address_from_bytes(script));
            case address_type::p2wsh:
            // Fall through
            case address_type::csv:
                return base58check_from_bytes(p2wsh_address_from_bytes(script));
            }
            __builtin_unreachable();
        }

        bool is_segwit_script_type(script_type type)
        {
            return type == script_type::p2sh_p2wsh_fortified_out || type == script_type::p2sh_p2wsh_csv_fortified_out
                || type == script_type::redeem_p2sh_p2wsh_fortified
                || type == script_type::redeem_p2sh_p2wsh_csv_fortified;
        }

        script_type get_script_type_from_address_type_string(const std::string& addr_type_str)
        {
            if (addr_type_str == "csv")
                return script_type::p2sh_p2wsh_csv_fortified_out;
            else if (addr_type_str == "p2wsh")
                return script_type::p2sh_p2wsh_fortified_out;
            GA_SDK_RUNTIME_ASSERT(addr_type_str == "p2sh");
            return script_type::p2sh_fortified_out;
        }
    } // namespace

    nlohmann::json session::session_impl::get_subaccounts() const
    {
        std::vector<nlohmann::json> subaccounts;
        subaccounts.reserve(m_subaccounts.size());
        for (auto s : m_subaccounts)
            subaccounts.push_back(s.second);
        return nlohmann::json(subaccounts);
    }

    nlohmann::json session::session_impl::get_subaccount(uint32_t subaccount) const
    {
        const auto p = m_subaccounts.find(subaccount);
        GA_SDK_RUNTIME_ASSERT(p != m_subaccounts.end());
        return p->second;
    }

    nlohmann::json session::session_impl::insert_subaccount(const std::string& name, uint32_t pointer,
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

    nlohmann::json session::session_impl::create_subaccount(const nlohmann::json& details)
    {
        const std::string name = details.at("name");
        const std::string type = details.at("type");
        std::string recovery_mnemonic;
        std::string pub_key;
        std::string chain_code;
        std::string recovery_pub_key;
        std::string recovery_chain_code;
        std::string recovery_xpub;

        const uint32_t pointer = m_next_subaccount;

        std::tie(pub_key, chain_code) = get_hdkey(m_master_key, pointer);
        if (type == "2of3") {
            // The user can provide a recovery mnemonic or xpub; if not,
            // we generate and return a mnemonic for them.
            const auto user_recovery_xpub = details.value("recovery_xpub", std::string());
            if (!user_recovery_xpub.empty()) {
                std::tie(recovery_pub_key, recovery_chain_code, recovery_xpub)
                    = get_recovery_key(user_recovery_xpub, pointer);
            } else {
                const auto user_recovery_mnemonic = details.value("recovery_mnemonic", std::string());
                if (user_recovery_mnemonic.empty()) {
                    recovery_mnemonic = generate_mnemonic();
                } else {
                    recovery_mnemonic = user_recovery_mnemonic; // User provided
                }
                std::tie(recovery_pub_key, recovery_chain_code, recovery_xpub)
                    = get_recovery_key(recovery_mnemonic, get_bip32_version(), pointer);
            }
        }

        std::string receiving_id;
        wamp_call([&receiving_id](wamp_call_result result) { receiving_id = result.get().argument<std::string>(0); },
            "com.greenaddress.txs.create_subaccount", pointer, name, pub_key, chain_code, recovery_pub_key,
            recovery_chain_code);

        ++m_next_subaccount;

        const bool has_txs = false;
        nlohmann::json subaccount
            = insert_subaccount(name, pointer, receiving_id, recovery_pub_key, recovery_chain_code, type, has_txs);
        if (type == "2of3") {
            subaccount["recovery_mnemonic"] = recovery_mnemonic;
            subaccount["recovery_xpub"] = recovery_xpub;
        }
        return subaccount;
    } // namespace sdk

    wally_ext_key_ptr session::session_impl::get_recovery_extkey(uint32_t subaccount) const
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
    void session::session_impl::change_settings(
        const std::string& key, const T& value, const nlohmann::json& twofactor_data)
    {
        bool r{ false };
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.login.change_settings", key, value, as_messagepack(twofactor_data).get());
        GA_SDK_RUNTIME_ASSERT(r);
    }

    void session::session_impl::change_settings_tx_limits(
        bool is_fiat, uint32_t per_tx, uint32_t total, const nlohmann::json& twofactor_data)
    {
        const nlohmann::json args = { { "is_fiat", is_fiat }, { "per_tx", per_tx }, { "total", total } };
        change_settings("tx_limits", as_messagepack(args).get(), twofactor_data);
    }

    void session::session_impl::change_settings_pricing_source(const std::string& currency, const std::string& exchange)
    {
        wamp_call([](boost::future<autobahn::wamp_call_result> result) { result.get(); },
            "com.greenaddress.login.set_pricing_source", currency, exchange);
    }

    nlohmann::json session::session_impl::get_transactions(uint32_t subaccount, uint32_t page_id)
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
        txs.erase("fiat_value");
        txs["page_id"] = page_id;
        json_add_if_missing(txs, "next_page_id", 0, true);

        for (auto& tx : txs["list"]) {
            const uint32_t tx_block_height = json_add_if_missing(tx, "block_height", 0, true);
            // TODO: Remove? subaccount has no meaning at the tx level
            json_add_if_missing(tx, "subaccount", 0, true);
            json_add_if_missing(tx, "has_payment_request", false);
            json_add_if_missing(tx, "memo", std::string());
            const std::string fee_str = tx["fee"];
            tx["fee"] = boost::lexical_cast<uint64_t>(fee_str);

            amount received, spent;
            bool is_from_me = false; // Are any inputs from our wallet?
            std::map<uint32_t, nlohmann::json> in_map, out_map;

            // Clean up and categorise the endpoints
            for (auto& ep : tx["eps"]) {
                ep.erase("id");
                json_add_if_missing(ep, "subaccount", 0, true);
                json_rename_key(ep, "pubkey_pointer", "pointer");
                json_rename_key(ep, "ad", "address");
                json_add_if_missing(ep, "pointer", 0, true);
                const std::string value_str = ep["value"];
                const auto value = boost::lexical_cast<uint64_t>(value_str);
                ep["value"] = value;

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

                const uint32_t pt_idx = ep["pt_idx"];
                auto& m = is_tx_output ? out_map : in_map;
                m.emplace(pt_idx, ep);
            }

            // Store the endpoints as inputs/outputs in tx index order
            nlohmann::json::array_t inputs, outputs;
            for (auto& it : in_map) {
                inputs.emplace_back(it.second);
            }
            tx["inputs"] = inputs;

            for (auto& it : out_map) {
                outputs.emplace_back(it.second);
            }
            tx["outputs"] = outputs;
            tx.erase("eps");

            // Compute tx economics and label addressees
            const bool net_positive = received > spent;
            const bool is_confirmed = tx_block_height != 0;
            std::vector<std::string> addressees;

            if (net_positive) {
                for (auto& ep : tx["inputs"]) {
                    std::string addressee;
                    if (!ep.value("is_relevant", false)) {
                        // Add unique addressees that aren't ourselves
                        addressee = ep.value("social_source", ep["address"]);
                        if (std::find(std::begin(addressees), std::end(addressees), addressee)
                            == std::end(addressees)) {
                            addressees.push_back(addressee);
                        }
                        ep["addressee"] = addressee;
                    }
                }
                tx["type"] = "incoming";
                tx["can_rbf"] = false;
                tx["can_cpfp"] = !is_confirmed;
            } else {
                for (auto& ep : tx["outputs"]) {
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
                            addressees.push_back(addressee);
                        }
                        ep["addressee"] = addressee;
                    }
                }
                tx["type"] = addressees.empty() ? "redeposit" : "outgoing";
                tx["can_rbf"] = !is_confirmed && tx.value("rbf_optin", false);
                tx["can_cpfp"] = false;
            }

            tx["addressees"] = addressees;

            const amount total = net_positive ? received - spent : spent - received;
            tx["value"] = total.value();
        }
        return txs;
    }

    void session::session_impl::subscribe(const std::string& topic, const autobahn::wamp_event_handler& callback)
    {
        auto subscribe_future = m_session->subscribe(topic, callback, autobahn::wamp_subscribe_options("exact"))
                                    .then([](boost::future<autobahn::wamp_subscription> subscription) {
                                        std::cerr << "subscribed to topic:" << subscription.get().id() << std::endl;
                                    });

        subscribe_future.get();
    }

    void session::session_impl::subscribe(
        const std::string& topic, std::function<void(const std::string& output)> callback)
    {
        subscribe(topic, [callback](const autobahn::wamp_event& event) {
            const auto ev = event.argument<msgpack::object>(0);
            std::stringstream strm;
            strm << ev;
            callback(strm.str());
        });
    }

    amount session::session_impl::get_dust_threshold() const
    {
        const amount::value_type v = m_login_data["dust"];
        return amount(v);
    }

    std::vector<unsigned char> session::session_impl::output_script(
        uint32_t subaccount, const nlohmann::json& data) const
    {
        GA_SDK_RUNTIME_ASSERT(!is_watch_only());
        const uint32_t pointer = data["pointer"];
        script_type type;

        auto addr_type = data.find("addr_type");
        if (addr_type != data.end()) {
            // Address
            // FIXME: set script_type in addresses returned from the API
            type = get_script_type_from_address_type_string(*addr_type);
        } else {
            type = data["script_type"];
        }
        uint32_t subtype = 0;
        if (type == script_type::p2sh_p2wsh_csv_fortified_out)
            subtype = data["subtype"];

        return ga::sdk::output_script(m_net_params, m_master_key, get_recovery_extkey(subaccount),
            m_login_data["gait_path"], type, subtype, subaccount, pointer);
    }

    template <typename T> nlohmann::json session::session_impl::get_unspent_outputs(T subaccount, uint32_t num_confs)
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
        return utxos;
    }

    nlohmann::json session::session_impl::get_transaction_details(const std::string& txhash) const
    {
        std::string tx_data;
        wamp_call([&tx_data](wamp_call_result result) { tx_data = result.get().argument<std::string>(0); },
            "com.greenaddress.txs.get_raw_output", txhash);
        // FIXME: Augment the returned information (size, vsize etc)
        return { { "txhash", txhash }, { "transaction", tx_data } };
    }

    nlohmann::json session::session_impl::get_receive_address(uint32_t subaccount, address_type addr_type) const
    {
        const std::string addr_type_str = get_address_type_string(addr_type);

        nlohmann::json address;
        wamp_call([&address](wamp_call_result result) { address = get_json_result(result.get()); },
            "com.greenaddress.vault.fund", subaccount, true, addr_type_str);

        const auto server_script = bytes_from_hex(address["script"]);
        const auto server_address = get_address_from_script(server_script, addr_type);

        if (!is_watch_only()) {
            // Compute the address locally to verify the servers data
            const auto user_script = output_script(subaccount, address);
            const auto user_address = get_address_from_script(user_script, addr_type);
            GA_SDK_RUNTIME_ASSERT(server_address == user_address);
        }

        address["address"] = server_address;
        return address;
    }

    template <typename T> nlohmann::json session::session_impl::get_balance(T subaccount, uint32_t num_confs) const
    {
        nlohmann::json b;
        wamp_call([&b](wamp_call_result result) { b = get_json_result(result.get()); },
            "com.greenaddress.txs.get_balance", subaccount, num_confs);
        return b;
    }

    nlohmann::json session::session_impl::get_available_currencies() const
    {
        nlohmann::json a;
        wamp_call([&a](wamp_call_result result) { a = get_json_result(result.get()); },
            "com.greenaddress.login.available_currencies");
        return a;
    }

    bool session::session_impl::is_rbf_enabled() const { return m_login_data["rbf"]; }

    bool session::session_impl::is_watch_only() const { return m_watch_only; }

    address_type session::session_impl::get_default_address_type() const
    {
        const auto& appearance = m_login_data["appearance"];
        if (appearance.value("use_csv", false))
            return address_type::csv;
        else if (appearance.value("use_segwit", false))
            return address_type::p2wsh;
        return address_type::p2sh;
    }

    nlohmann::json session::session_impl::get_twofactor_config()
    {
        nlohmann::json f;
        wamp_call([&f](wamp_call_result result) { f = get_json_result(result.get()); },
            "com.greenaddress.twofactor.get_config");
        return f;
    }

    void session::session_impl::set_email(const std::string& email, const nlohmann::json& twofactor_data)
    {
        wamp_call([](wamp_call_result result) { result.get(); }, "com.greenaddress.twofactor.set_email", email,
            as_messagepack(twofactor_data).get());
    }

    void session::session_impl::activate_email(const std::string& code)
    {
        wamp_call([](wamp_call_result result) { result.get(); }, "com.greenaddress.twofactor.activate_email", code);
    }

    void session::session_impl::init_enable_twofactor(
        const std::string& method, const std::string& data, const nlohmann::json& twofactor_data)
    {
        const std::string api_method = "com.greenaddress.twofactor.init_enable_" + method;
        wamp_call(
            [](wamp_call_result result) { result.get(); }, api_method, data, as_messagepack(twofactor_data).get());
    }

    void session::session_impl::enable_twofactor(const std::string& method, const std::string& code)
    {
        std::string api_method = "com.greenaddress.twofactor.enable_" + method;
        wamp_call([](wamp_call_result result) { result.get(); }, api_method, code);
    }

    void session::session_impl::enable_gauth(const std::string& code, const nlohmann::json& twofactor_data)
    {
        wamp_call([](wamp_call_result result) { result.get(); }, "com.greenaddress.twofactor.enable_gauth", code,
            as_messagepack(twofactor_data).get());
    }

    void session::session_impl::disable_twofactor(const std::string& method, const nlohmann::json& twofactor_data)
    {
        const std::string api_method = "com.greenaddress.twofactor.disable_" + method;
        wamp_call([](wamp_call_result result) { result.get(); }, api_method, as_messagepack(twofactor_data).get());
    }

    void session::session_impl::twofactor_request_code(
        const std::string& method, const std::string& action, const nlohmann::json& twofactor_data)
    {
        const std::string api_method = "com.greenaddress.twofactor.request_" + method;
        wamp_call(
            [](wamp_call_result result) { result.get(); }, api_method, action, as_messagepack(twofactor_data).get());
    }

    nlohmann::json session::session_impl::set_pin(
        const std::string& mnemonic, const std::string& pin, const std::string& device)
    {
        mnemonic_validate("en", mnemonic);

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
        // const auto mnemonic_bytes = mnemonic_to_bytes(mnemonic, "en");

        // TODO: Get password from pin.set_pin_login when server is updated
        const auto password = get_pin_password(pin, pin_identifier);

        // Encrypt the users mnemonic and seed using a key dervied from the
        // PIN password and a randomly generated salt.
        // Note the use of base64 here is to remain binary compatible with
        // old GreenBits installs.
        const auto salt = get_random_bytes<16>();
        const auto salt_b64 = boost::beast::detail::base64_encode(salt.data(), salt.size());
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

    std::vector<unsigned char> session::session_impl::get_pin_password(
        const std::string& pin, const std::string& pin_identifier)
    {
        std::string password;
        wamp_call([&password](wamp_call_result result) { password = result.get().argument<std::string>(0); },
            "com.greenaddress.pin.get_password", pin, pin_identifier);

        return std::vector<unsigned char>(password.begin(), password.end());
    }

    bool session::session_impl::add_address_book_entry(const std::string& address, const std::string& name)
    {
        bool r{ false };
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.addressbook.add_entry", address, name, 0);
        return r;
    }

    bool session::session_impl::edit_address_book_entry(const std::string& address, const std::string& name)
    {
        bool r{ false };
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.addressbook.edit_entry", address, name, 0);
        return r;
    }

    void session::session_impl::delete_address_book_entry(const std::string& address)
    {
        wamp_call([](wamp_call_result result) { result.get(); }, "com.greenaddress.addressbook.delete_entry", address);
    }

    // Add a UTXO to a transaction. Returns the amount added
    amount session::session_impl::add_utxo(const wally_tx_ptr& tx, const nlohmann::json& u) const
    {
        const std::string txhash = u["txhash"];
        const uint32_t index = u["pt_idx"];
        const uint32_t sequence = is_rbf_enabled() ? 0xFFFFFFFD : 0xFFFFFFFE;
        const uint32_t subaccount = u.value("subaccount", 0);
        const auto type = script_type(u["script_type"]);

        // TODO: Create correctly sized dummys instead of actual script (faster)
        const auto prevout_script = output_script(subaccount, u);
        wally_tx_witness_stack_ptr wit;

        if (is_segwit_script_type(type)) {
            // TODO: If the UTXO is CSV and expired, spend it using the users key only (smaller)
            wit = tx_witness_stack_init(4);
            tx_witness_stack_add_dummy(wit, WALLY_TX_DUMMY_NULL);
            tx_witness_stack_add_dummy(wit, WALLY_TX_DUMMY_SIG);
            tx_witness_stack_add_dummy(wit, WALLY_TX_DUMMY_SIG);
            tx_witness_stack_add(wit, prevout_script);
        }

        tx_add_raw_input(tx, bytes_from_hex_rev(txhash), index, sequence,
            wit ? DUMMY_WITNESS_SCRIPT : dummy_input_script(prevout_script), wit, 0);

        const std::string v = u["value"]; // FIXME: Allow amount conversions directly
        return amount{ std::stoull(v, nullptr, 10) };
    }

    void session::session_impl::sign_input(const wally_tx_ptr& tx, uint32_t index, const nlohmann::json& u) const
    {
        const auto txhash = u["txhash"];
        const uint32_t subaccount = u.value("subaccount", 0);
        const uint32_t pointer = u["pointer"];
        const std::string v = u["value"];
        const amount satoshi{ std::stoull(v, nullptr, 10) };
        const script_type type = script_type(u["script_type"]);

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

    amount session::session_impl::get_tx_fee(const wally_tx_ptr& tx, amount fee_rate)
    {
        const amount::value_type v = m_login_data["min_fee"];
        const amount min_fee_rate(v);
        const amount rate = fee_rate < min_fee_rate ? min_fee_rate : fee_rate;

        const size_t vsize = tx_get_vsize(tx);

        const auto fee = static_cast<double>(vsize) * rate.value() / 1000.0;
        const auto rounded_fee = static_cast<amount::value_type>(std::ceil(fee));

        return amount{ rounded_fee };
    }

    std::string session::session_impl::make_raw_tx(const std::vector<std::pair<std::string, amount>>& address_amount,
        const nlohmann::json& utxos, amount fee_rate, bool send_all)
    {
        GA_SDK_RUNTIME_ASSERT(!address_amount.empty() && (!send_all || address_amount.size() == 1));

        auto tx = tx_init(m_block_height, utxos.size(), address_amount.size() + 1);

        amount total, fee;
        amount required_total{ 0 };
        required_total = std::accumulate(std::begin(address_amount), std::end(address_amount), required_total,
            [](const amount& l, const auto& r) { return l + r.second; });

        uint32_t change_subaccount = utxos[0]["subaccount"];
        if (std::find_if(std::begin(utxos), std::end(utxos),
                [change_subaccount](const nlohmann::json& u) { return u["subaccount"] != change_subaccount; })
            != std::end(utxos)) {
            // Send change to main when sending from multiple subaccounts
            change_subaccount = 0;
        }

        for (auto&& u : utxos) {
            if (!send_all && total >= required_total) {
                break;
            }
            total += add_utxo(tx, u);
        }

        for (auto&& aa : address_amount) {
            tx_add_raw_output(tx, aa.second.value(), output_script_for_address(m_net_params, aa.first), 0);
        }

        bool have_change = false;
        const amount dust_threshold = get_dust_threshold();

        for (;;) {
            fee = get_tx_fee(tx, fee_rate);
            const amount min_change = have_change ? amount() : dust_threshold;
            const amount am = required_total + fee + min_change;
            if (total < am) {
                if (tx->num_inputs == utxos.size()) {
                    throw std::runtime_error("insufficient funds");
                }

                total += add_utxo(tx, utxos[tx->num_inputs]);
                continue;
            }

            if (total == am || have_change) {
                break;
            }

            const auto addr_type = get_default_address_type();
            const auto change_address = get_receive_address(change_subaccount, addr_type);
            const auto change_output_script = output_script_for_address(m_net_params, change_address["address"]);
            tx_add_raw_output(tx, 0, change_output_script, 0);
            have_change = true;
        }

        if (have_change) {
            // Set the change amount
            tx->outputs[tx->num_outputs - 1].satoshi = (total - required_total - fee).value();
            // FIXME: Randomize change output
        }

        auto ub = utxos.begin();
        for (uint32_t i = 0; i < tx->num_inputs; ++i) {
            sign_input(tx, i, *ub++);
        }

        return hex_from_bytes(tx_to_bytes(tx));
    }

    nlohmann::json session::session_impl::send(const std::string& tx_hex, const nlohmann::json& twofactor_data)
    {
        const size_t MAX_TX_WEIGHT = 400000;
        const auto tx = tx_from_hex(tx_hex, WALLY_TX_FLAG_USE_WITNESS);
        GA_SDK_RUNTIME_ASSERT(tx_get_weight(tx) < MAX_TX_WEIGHT);

        // FIXME: priv_data, pass return_tx=true
        nlohmann::json tx_details;
        wamp_call([&tx_details](wamp_call_result result) { tx_details = get_json_result(result.get()); },
            "com.greenaddress.vault.send_raw_tx", tx_hex, as_messagepack(twofactor_data).get());
        // FIXME: update cached limits and augment returned data to match get_transaction_details
        tx_details.erase("new_limit");
        return tx_details;
    }

    nlohmann::json session::session_impl::send(const std::vector<std::pair<std::string, amount>>& address_amount,
        const nlohmann::json& utxos, amount fee_rate, bool send_all, const nlohmann::json& twofactor_data)
    {
        return send(make_raw_tx(address_amount, utxos, fee_rate, send_all), twofactor_data);
    }

    template <typename T>
    nlohmann::json session::session_impl::send(T subaccount,
        const std::vector<std::pair<std::string, amount>>& address_amount, amount fee_rate, bool send_all,
        const nlohmann::json& twofactor_data)
    {
        const uint32_t required_confs = 1; // FIXME: 0 for testnet?
        const auto utxos = get_unspent_outputs(subaccount, required_confs);

        return send(address_amount, utxos, fee_rate, send_all, twofactor_data);
    }

    void session::session_impl::send_nlocktimes()
    {
        bool r;
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.login.send_nlocktime");
        GA_SDK_RUNTIME_ASSERT(r);
    }

    void session::session_impl::set_transaction_memo(
        const std::string& txhash_hex, const std::string& memo, const std::string& memo_type)
    {
        wamp_call([](boost::future<autobahn::wamp_call_result> result) { result.get(); },
            "com.greenaddress.txs.change_memo", txhash_hex, memo, memo_type);
    }

    template <typename F, typename... Args> auto session::exception_wrapper(F&& f, Args&&... args)
    {
        try {
            return f(std::forward<Args>(args)...);
        } catch (const autobahn::abort_error& e) {
            disconnect();
            throw reconnect_error();
        } catch (const autobahn::network_error& e) {
            disconnect();
            throw reconnect_error();
        } catch (const autobahn::no_transport_error& e) {
            disconnect();
            throw reconnect_error();
        } catch (const autobahn::protocol_error& e) {
            disconnect();
            throw reconnect_error();
        } catch (const std::exception& e) {
            throw;
        }
        __builtin_unreachable();
    }

    void session::connect(network_parameters params, bool debug)
    {
        exception_wrapper([&] {
            m_impl = std::make_unique<session::session_impl>(std::move(params), debug);
            m_impl->connect();
        });
    }

    session::session() = default;
    session::~session() = default;

    void session::disconnect() { m_impl.reset(); }

    void session::register_user(const std::string& mnemonic, const std::string& user_agent)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);

        exception_wrapper([&] { m_impl->register_user(mnemonic, user_agent); });
    }

    void session::login(const std::string& mnemonic, const std::string& user_agent)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->login(mnemonic, user_agent); });
    }

    void session::login(const std::string& pin, const nlohmann::json& pin_data, const std::string& user_agent)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->login(pin, pin_data, user_agent); });
    }

    void session::login_watch_only(
        const std::string& username, const std::string& password, const std::string& user_agent)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->login_watch_only(username, password, user_agent); });
    }

    bool session::set_watch_only(const std::string& username, const std::string& password)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->set_watch_only(username, password); });
    }

    bool session::remove_account(const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->remove_account(twofactor_data); });
    }

    nlohmann::json session::create_subaccount(const nlohmann::json& details)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->create_subaccount(details); });
    }

    nlohmann::json session::get_subaccounts()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_subaccounts(); });
    }

    void session::change_settings_privacy_send_me(privacy_send_me value)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->change_settings("privacy.send_me", int(value), nlohmann::json()); });
    }

    void session::change_settings_privacy_show_as_sender(privacy_show_as_sender value)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper(
            [&] { m_impl->change_settings("privacy.show_as_sender", int(value), nlohmann::json()); });
    }

    void session::change_settings_tx_limits(
        bool is_fiat, uint32_t per_tx, uint32_t total, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->change_settings_tx_limits(is_fiat, per_tx, total, twofactor_data); });
    }

    void session::change_settings_pricing_source(const std::string& currency, const std::string& exchange)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->change_settings_pricing_source(currency, exchange); });
    }

    nlohmann::json session::get_transactions(uint32_t subaccount, uint32_t page_id)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_transactions(subaccount, page_id); });
    }

    void session::subscribe(const std::string& topic, std::function<void(const std::string& output)> callback)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->subscribe(topic, callback); });
    }

    nlohmann::json session::get_receive_address(uint32_t subaccount, address_type addr_type)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_receive_address(subaccount, addr_type); });
    }

    nlohmann::json session::get_balance(uint32_t num_confs)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_balance("all", num_confs); });
    }

    nlohmann::json session::get_balance(uint32_t subaccount, uint32_t num_confs)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_balance(subaccount, num_confs); });
    }

    nlohmann::json session::get_available_currencies()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_available_currencies(); });
    }

    bool session::is_rbf_enabled()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->is_rbf_enabled(); });
    }

    bool session::is_watch_only()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->is_watch_only(); });
    }

    address_type session::get_default_address_type()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_default_address_type(); });
    }

    nlohmann::json session::get_twofactor_config()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_twofactor_config(); });
    }

    void session::set_email(const std::string& email, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->set_email(email, twofactor_data); });
    }

    void session::activate_email(const std::string& code)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->activate_email(code); });
    }

    void session::init_enable_twofactor(
        const std::string& method, const std::string& data, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->init_enable_twofactor(method, data, twofactor_data); });
    }

    void session::enable_twofactor(const std::string& method, const std::string& code)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->enable_twofactor(method, code); });
    }

    void session::enable_gauth(const std::string& code, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->enable_gauth(code, twofactor_data); });
    }

    void session::disable_twofactor(const std::string& method, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->disable_twofactor(method, twofactor_data); });
    }

    void session::twofactor_request_code(
        const std::string& method, const std::string& action, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->twofactor_request_code(method, action, twofactor_data); });
    }

    nlohmann::json session::set_pin(const std::string& mnemonic, const std::string& pin, const std::string& device)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->set_pin(mnemonic, pin, device); });
    }

    bool session::add_address_book_entry(const std::string& address, const std::string& name)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->add_address_book_entry(address, name); });
    }

    bool session::edit_address_book_entry(const std::string& address, const std::string& name)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->edit_address_book_entry(address, name); });
    }

    void session::delete_address_book_entry(const std::string& address)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->delete_address_book_entry(address); });
    }

    nlohmann::json session::get_unspent_outputs(uint32_t num_confs)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_unspent_outputs("all", num_confs); });
    }

    nlohmann::json session::get_unspent_outputs(uint32_t subaccount, uint32_t num_confs)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_unspent_outputs(subaccount, num_confs); });
    }

    std::string session::make_raw_tx(const std::vector<std::pair<std::string, amount>>& address_amount,
        const nlohmann::json& utxos, amount fee_rate, bool send_all)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->make_raw_tx(address_amount, utxos, fee_rate, send_all); });
    }

    nlohmann::json session::send(const std::string& tx_hex, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->send(tx_hex, twofactor_data); });
    }

    nlohmann::json session::send(const std::vector<std::pair<std::string, amount>>& address_amount,
        const nlohmann::json& utxos, amount fee_rate, bool send_all, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper(
            [&] { return m_impl->send(address_amount, utxos, fee_rate, send_all, twofactor_data); });
    }

    nlohmann::json session::send(uint32_t subaccount, const std::vector<std::pair<std::string, amount>>& address_amount,
        amount fee_rate, bool send_all, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper(
            [&] { return m_impl->send(subaccount, address_amount, fee_rate, send_all, twofactor_data); });
    }

    nlohmann::json session::send(const std::vector<std::pair<std::string, amount>>& address_amount, amount fee_rate,
        bool send_all, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper(
            [&] { return m_impl->send("all", address_amount, fee_rate, send_all, twofactor_data); });
    }

    void session::send_nlocktimes()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->send_nlocktimes(); });
    }

    void session::set_transaction_memo(
        const std::string& txhash_hex, const std::string& memo, const std::string& memo_type)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->set_transaction_memo(txhash_hex, memo, memo_type); });
    }

    nlohmann::json session::get_transaction_details(const std::string& txhash_hex)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_transaction_details(txhash_hex); });
    }

    std::string session::get_system_message()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_system_message(); });
    }

    nlohmann::json session::get_fee_estimates()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_fee_estimates(); });
    }

    std::string session::get_mnemonic_passphrase(const std::string& password)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_mnemonic_passphrase(password); });
    }

    void session::ack_system_message(const std::string& system_message)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->ack_system_message(system_message); });
    }
} // namespace sdk
} // namespace ga
