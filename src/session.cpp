#include <algorithm>
#include <array>
#include <ctime>
#include <map>
#include <queue>
#include <thread>
#include <type_traits>
#include <vector>

#include <gsl/span>

#include "boost_wrapper.hpp"

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
    static const std::string DEFAULT_USER_AGENT("[v2,sw]");
    static const unsigned char GA_LOGIN_NONCE[30] = { 'G', 'r', 'e', 'e', 'n', 'A', 'd', 'd', 'r', 'e', 's', 's', '.',
        'i', 't', ' ', 'H', 'D', ' ', 'w', 'a', 'l', 'l', 'e', 't', ' ', 'p', 'a', 't', 'h' };

    // Dummy data for transaction creation with correctly sized data for fee estimation
    static const std::vector<unsigned char> DUMMY_WITNESS_SCRIPT(3 + SHA256_LEN);

    namespace {
        std::once_flag one_time_setup_flag;

        void one_time_setup()
        {
            std::call_once(one_time_setup_flag, [] {
                wally::init(0);
                wally::secp_randomize(get_random_bytes<WALLY_SECP_RANDOMISE_LEN>());
            });
        }

        // FIXME: too slow. lacks validation.
        std::array<unsigned char, 32> uint256_to_base256(const std::string& bytes)
        {
            constexpr size_t base = 256;

            std::array<unsigned char, 32> repr;
            size_t i = repr.size() - 1;
            for (boost::multiprecision::checked_uint256_t num(bytes); num; num = num / base, --i) {
                repr[i] = static_cast<unsigned char>(num % base);
            }

            return repr;
        }
    }

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
        session_impl(network_parameters params, bool debug)
            : m_controller(m_io)
            , m_params(std::move(params))
            , m_block_height(0)
            , m_master_key(nullptr)
            , m_debug(debug)
        {
            one_time_setup();
            connect_with_tls() ? make_client<client_tls>() : make_client<client>();
        }

        session_impl(const session_impl& other) = delete;
        session_impl(session_impl&& other) noexcept = delete;
        session_impl& operator=(const session_impl& other) = delete;
        session_impl& operator=(session_impl&& other) noexcept = delete;

        ~session_impl() { m_io.stop(); }

        void connect();
        void register_user(const std::string& mnemonic, const std::string& user_agent);
        login_data login(const std::string& mnemonic, const std::string& user_agent);
        login_data login_watch_only(
            const std::string& username, const std::string& password, const std::string& user_agent);
        bool set_watch_only(const std::string& username, const std::string& password);
        bool remove_account();

        std::pair<std::string, std::string> create_subaccount(
            subaccount_type type, const std::string& name, const std::string& xpub);

        login_data login(const std::string& pin, const std::pair<std::string, std::string>& pin_identifier_and_secret,
            const std::string& user_agent = std::string());
        void change_settings_helper(settings key, const std::map<int, int>& args);

        tx_list get_tx_list(const std::pair<std::time_t, std::time_t>& date_range, size_t subaccount,
            tx_list_sort_by sort_by, size_t page_id, const std::string& query);
        void subscribe(const std::string& topic, const autobahn::wamp_event_handler& callback);
        void subscribe(const std::string& topic, std::function<void(const std::string& output)> callback);
        std::vector<subaccount> get_subaccounts() { return m_login_data.get_subaccounts(); }
        receive_address get_receive_address(address_type addr_type, size_t subaccount) const;
        template <typename T> balance get_balance(T subaccount, size_t num_confs) const;
        available_currencies get_available_currencies() const;
        bool is_rbf_enabled() const;

        two_factor get_twofactor_config();
        bool set_twofactor(two_factor_type type, const std::string& code, const std::string& proxy_code);

        pin_info set_pin(const std::string& mnemonic, const std::string& pin, const std::string& device);

        bool add_address_book_entry(const std::string& address, const std::string& name, size_t rating);
        bool edit_address_book_entry(const std::string& address, const std::string& name, size_t rating);
        void delete_address_book_entry(const std::string& address);

        utxo_set get_utxos(size_t num_confs, size_t subaccount);
        std::string make_raw_tx(const std::vector<std::pair<std::string, amount>>& address_amount,
            const std::vector<utxo>& utxos, amount fee_rate, bool send_all);
        void send(const std::string& tx_hex);
        void send(const std::vector<std::pair<std::string, amount>>& address_amount, const std::vector<utxo>& utxos,
            amount fee_rate, bool send_all);
        void send(const std::vector<std::pair<std::string, amount>>& address_amount, amount fee_rate, bool send_all);

    private:
        static std::pair<std::string, std::string> sign_challenge(
            const wally_ext_key_ptr& master_key, const std::string& challenge);

        bool connect_with_tls() const
        {
            return boost::algorithm::starts_with(
                !m_params.get_use_tor() ? m_params.gait_wamp_url() : m_params.gait_onion(), "wss://");
        }

        template <typename T> std::enable_if_t<std::is_same<T, client>::value> set_tls_init_handler() {}
        template <typename T> std::enable_if_t<std::is_same<T, client_tls>::value> set_tls_init_handler()
        {
            // FIXME: these options need to be checked.
            boost::get<std::unique_ptr<T>>(m_client)->set_tls_init_handler([](websocketpp::connection_hdl) {
                context_ptr ctx = std::make_shared<boost::asio::ssl::context>(boost::asio::ssl::context::tlsv12);
                ctx->set_options(boost::asio::ssl::context::default_workarounds | boost::asio::ssl::context::no_sslv2
                    | boost::asio::ssl::context::no_sslv3 | boost::asio::ssl::context::no_tlsv1
                    | boost::asio::ssl::context::no_tlsv1_1 | boost::asio::ssl::context::single_dh_use);
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
                !m_params.get_use_tor() ? m_params.gait_wamp_url() : m_params.gait_onion(), m_params.get_proxy(),
                m_debug);
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
            const auto status = m_session->call(method_name, std::make_tuple(std::forward<Args>(args)...), call_options)
                                    .then(std::forward<F>(body))
                                    .wait_for(boost::chrono::seconds(timeout));
            if (status == boost::future_status::timeout) {
                throw timeout_error{};
            }
            GA_SDK_RUNTIME_ASSERT(status == boost::future_status::ready);
        }

        std::vector<unsigned char> get_pin_password(const std::string& pin, const std::string& pin_identifier);

        amount get_dust_threshold() const;
        std::string get_raw_output(const std::string& txhash) const;
        std::vector<unsigned char> output_script(uint32_t subaccount, uint32_t pointer) const;
        amount add_utxo(const wally_tx_ptr& tx, const utxo& u) const;
        void sign_input(const wally_tx_ptr& tx, uint32_t index, const utxo& u) const;
        amount get_tx_fee(const wally_tx_ptr& tx, amount fee_rate);

    private:
        uint32_t get_bip32_version() const
        {
            return m_params.main_net() ? BIP32_VER_MAIN_PRIVATE : BIP32_VER_TEST_PRIVATE;
        }

        boost::asio::io_service m_io;
        boost::variant<std::unique_ptr<client>, std::unique_ptr<client_tls>> m_client;
        boost::variant<std::shared_ptr<transport>, std::shared_ptr<transport_tls>> m_transport;
        wamp_session_ptr m_session;

        event_loop_controller m_controller;

        network_parameters m_params;

        login_data m_login_data;
        fee_estimates m_fee_estimates;
        std::atomic<size_t> m_block_height;
        wally_ext_key_ptr m_master_key;

        bool m_debug;
    };

    void session::session_impl::connect()
    {
        m_session = std::make_shared<autobahn::wamp_session>(m_io, m_debug);

        const bool tls = connect_with_tls();
        tls ? make_transport<transport_tls>() : make_transport<transport>();
        tls ? connect_to_endpoint<transport_tls>() : connect_to_endpoint<transport>();
    }

    std::pair<std::string, std::string> session::session_impl::sign_challenge(
        const wally_ext_key_ptr& master_key, const std::string& challenge)
    {
        auto path_bytes = get_random_bytes<8>();

        std::array<uint32_t, 4> path;
        adjacent_transform(std::begin(path_bytes), std::end(path_bytes), std::begin(path),
            [](auto first, auto second) { return uint32_t((first << 8) + second); });

        secure_array<unsigned char, EC_PRIVATE_KEY_LEN> login_priv_key;
        derive_private_key(master_key, path, login_priv_key);

        const auto challenge_hash = uint256_to_base256(challenge);
        std::array<unsigned char, EC_SIGNATURE_LEN> sig;
        ec_sig_from_bytes(login_priv_key, challenge_hash, EC_FLAG_ECDSA, sig);

        return { hex_from_bytes(ec_sig_to_der(sig)), hex_from_bytes(path_bytes) };
    }

    void session::session_impl::register_user(const std::string& mnemonic, const std::string& user_agent)
    {
        secure_array<unsigned char, BIP39_SEED_LEN_512> seed;
        bip39_mnemonic_to_seed(mnemonic, nullptr, seed);

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

    login_data session::session_impl::login(const std::string& mnemonic, const std::string& user_agent)
    {
        secure_array<unsigned char, BIP39_SEED_LEN_512> seed;
        bip39_mnemonic_to_seed(mnemonic, nullptr, seed);

        // FIXME: Allocate m_master_key in mlocked memory and pass it
        ext_key* p;
        bip32_key_from_seed_alloc(seed, get_bip32_version(), 0, &p);

        m_master_key = wally_ext_key_ptr(p);

        unsigned char btc_ver[1] = { m_params.btc_version() };
        std::array<unsigned char, sizeof(btc_ver) + sizeof(m_master_key->hash160)> vpkh;
        init_container(vpkh, gsl::make_span(btc_ver), gsl::make_span(m_master_key->hash160));

        std::string challenge;
        wamp_call([&challenge](wamp_call_result result) { challenge = result.get().argument<std::string>(0); },
            "com.greenaddress.login.get_challenge", base58check_from_bytes(vpkh));

        const auto hexder_path = sign_challenge(m_master_key, challenge);
        wamp_call([this](wamp_call_result result) { m_login_data = result.get().argument<msgpack::object>(0); },
            "com.greenaddress.login.authenticate", hexder_path.first, false, hexder_path.second,
            std::string("fake_dev_id"), DEFAULT_USER_AGENT + user_agent + "_ga_sdk");

        m_block_height = m_login_data.get<size_t>("block_height");
        subscribe("com.greenaddress.blocks", [this](const autobahn::wamp_event& event) {
            block_event block_ev;
            block_ev = event.argument<msgpack::object>(0);
            const auto count = block_ev.get<size_t>("count");
            GA_SDK_RUNTIME_ASSERT(count >= m_block_height);
            m_block_height = count;
        });

        m_fee_estimates = m_login_data.get<msgpack::object>("fee_estimates");
        subscribe("com.greenaddress.fee_estimates",
            [this](const autobahn::wamp_event& event) { m_fee_estimates = event.argument<msgpack::object>(0); });

        return m_login_data;
    }

    login_data session::session_impl::login_watch_only(
        const std::string& username, const std::string& password, const std::string& user_agent)
    {
        wamp_call([this](wamp_call_result result) { m_login_data = result.get().argument<msgpack::object>(0); },
            "com.greenaddress.login.watch_only_v2", "custom",
            std::map<std::string, std::string>({ { "username", username }, { "password", password } }),
            DEFAULT_USER_AGENT + user_agent + "_ga_sdk");

        return m_login_data;
    }

    bool session::session_impl::set_watch_only(const std::string& username, const std::string& password)
    {
        bool r;
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.addressbook.sync_custom", username, password);
        return r;
    }

    bool session::session_impl::remove_account()
    {
        bool r;
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.login.remove_account", std::map<std::string, std::string>{});
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

        auto get_recovery_key(const std::string& mnemonic, uint32_t bip32_version, uint32_t pointer)
        {
            secure_array<unsigned char, BIP39_SEED_LEN_512> seed;
            bip39_mnemonic_to_seed(mnemonic, nullptr, seed);

            ext_key* p;
            bip32_key_from_seed_alloc(seed, bip32_version, BIP32_FLAG_SKIP_HASH, &p);
            wally_ext_key_ptr recovery{ p };

            std::array<unsigned char, BIP32_SERIALIZED_LEN> recovery_bytes;
            bip32_key_serialize(recovery, BIP32_FLAG_KEY_PUBLIC, recovery_bytes);

            std::string recovery_xpub = base58check_from_bytes(recovery_bytes);

            std::string recovery_pub_key;
            std::string recovery_chain_code;
            std::tie(recovery_pub_key, recovery_chain_code) = get_hdkey(recovery, pointer, false);

            return std::make_tuple(recovery_pub_key, recovery_chain_code, recovery_xpub);
        }
    }

    std::pair<std::string, std::string> session::session_impl::create_subaccount(
        subaccount_type type, const std::string& name, const std::string& xpub)
    {
        GA_SDK_RUNTIME_ASSERT(!name.empty());
        GA_SDK_RUNTIME_ASSERT_MSG(xpub.empty(), "not supported");

        std::string recovery_mnemonic;
        std::string pub_key;
        std::string recovery_pub_key;
        std::string chain_code;
        std::string recovery_chain_code;
        std::string recovery_xpub;

        const uint32_t pointer = m_login_data.get_min_unused_pointer();
        {
            std::tie(pub_key, chain_code) = get_hdkey(m_master_key, pointer);
            if (type == subaccount_type::_2of3) {
                recovery_mnemonic = generate_mnemonic();
                std::tie(recovery_pub_key, recovery_chain_code, recovery_xpub)
                    = get_recovery_key(recovery_mnemonic, get_bip32_version(), pointer);
            }
        }

        std::string receiving_id;
        auto&& create_subaccount = [this, &receiving_id](auto&&... args) {
            wamp_call(
                [&receiving_id](wamp_call_result result) { receiving_id = result.get().argument<std::string>(0); },
                "com.greenaddress.txs.create_subaccount", args...);
        };

        if (type == subaccount_type::_2of2) {
            create_subaccount(pointer, name, pub_key, chain_code);
        } else {
            create_subaccount(pointer, name, pub_key, chain_code, recovery_pub_key, recovery_chain_code);
        }

        m_login_data.insert_subaccount(name, pointer, receiving_id, recovery_pub_key, recovery_chain_code,
            type == subaccount_type::_2of2 ? "simple" : "2of3");

        return std::make_pair(recovery_mnemonic, recovery_xpub);
    }

    void session::session_impl::change_settings_helper(settings key, const std::map<int, int>& args)
    {
        auto&& to_args = [args](std::vector<std::string> v) {
            std::map<std::string, int> str_args;
            for (auto&& elem : args) {
                str_args[v[elem.first]] = elem.second;
            }
            return str_args;
        };

        std::string key_str;
        std::map<std::string, int> str_args;
        switch (key) {
        default:
            __builtin_unreachable();
        case settings::privacy_send_me:
            key_str = "privacy.send_me";
            break;
        case settings::privacy_show_as_sender:
            key_str = "privacy.show_as_sender";
            break;
        case settings::tx_limits:
            key_str = "tx_limits";
            break;
        }

        auto&& change_settings = [this, &key_str](auto arg) {
            wamp_call([](wamp_call_result result) { GA_SDK_RUNTIME_ASSERT(result.get().argument<bool>(0)); },
                "com.greenaddress.login.change_settings", key_str, arg);
        };

        if (key == settings::tx_limits) {
            change_settings(to_args({ "is_fiat", "per_tx", "total" }));
        } else {
            GA_SDK_RUNTIME_ASSERT(!args.empty());
            change_settings((*args.begin()).first);
        }
    }

    tx_list session::session_impl::get_tx_list(const std::pair<std::time_t, std::time_t>& date_range, size_t subaccount,
        tx_list_sort_by sort_by, size_t page_id, const std::string& query)
    {
        auto&& sort_by_str = [sort_by] {
            switch (sort_by) {
            default:
                __builtin_unreachable();
            case tx_list_sort_by::timestamp:
                return "ts";
            case tx_list_sort_by::timestamp_ascending:
                return "+ts";
            case tx_list_sort_by::timestamp_descending:
                return "-ts";
            case tx_list_sort_by::value:
                return "value";
            case tx_list_sort_by::value_ascending:
                return "+value";
            case tx_list_sort_by::value_descending:
                return "-value";
            }
        };

        auto&& date_range_str = [&date_range] {
            constexpr auto iso_str_siz = sizeof "0000-00-00T00:00:00.000Z";

            if (date_range.first == 0 && date_range.second == 0) {
                return std::make_pair(std::string(), std::string());
            }

            std::array<char, iso_str_siz> begin_date_str = { { 0 } };
            std::array<char, iso_str_siz> end_date_str = { { 0 } };

            struct tm tm_;
            std::strftime(
                begin_date_str.data(), begin_date_str.size(), "%FT%T.000Z", gmtime_r(&date_range.first, &tm_));
            std::strftime(end_date_str.data(), end_date_str.size(), "%FT%T.000Z", gmtime_r(&date_range.second, &tm_));

            return std::make_pair(std::string(begin_date_str.data()), std::string(end_date_str.data()));
        };

        tx_list txs;
        wamp_call([&txs](wamp_call_result result) { txs = result.get().argument<msgpack::object>(0); },
            "com.greenaddress.txs.get_list_v2", page_id, query, sort_by_str(), date_range_str(), subaccount);
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
        return amount{ m_login_data.get<amount::value_type>("dust") };
    }

    std::string session::session_impl::get_raw_output(const std::string& txhash) const
    {
        std::string raw_output;
        wamp_call([&raw_output](wamp_call_result result) { raw_output = result.get().argument<std::string>(0); },
            "com.greenaddress.txs.get_raw_output", txhash);
        return raw_output;
    }

    std::vector<unsigned char> session::session_impl::output_script(uint32_t subaccount, uint32_t pointer) const
    {
        GA_SDK_RUNTIME_ASSERT(!m_params.deposit_chain_code().empty());
        GA_SDK_RUNTIME_ASSERT(!m_params.deposit_pub_key().empty());
        return ga::sdk::output_script(m_master_key, m_params.deposit_chain_code(), m_params.deposit_pub_key(),
            m_login_data.get<std::string>("gait_path"), subaccount, pointer, m_params.main_net());
    }

    utxo_set session::session_impl::get_utxos(size_t num_confs, size_t subaccount)
    {
        utxo_set unspent;
        wamp_call(
            [&unspent](wamp_call_result result) {
                const auto r = result.get();
                if (r.number_of_arguments()) {
                    unspent = r.argument<msgpack::object>(0);
                }
            },
            "com.greenaddress.txs.get_all_unspent_outputs", num_confs, subaccount, "any");
        return unspent;
    }

    receive_address session::session_impl::get_receive_address(address_type addr_type, size_t subaccount) const
    {
        const std::string addr_type_str = addr_type == address_type::p2sh ? "p2sh" : "p2wsh";

        receive_address address;
        wamp_call([&address](wamp_call_result result) { address = result.get().argument<msgpack::object>(0); },
            "com.greenaddress.vault.fund", subaccount, true, addr_type_str);

        const auto script_bytes = bytes_from_hex(address.get<std::string>("script"));

        const auto sc = addr_type == address_type::p2sh ? p2sh_address_from_bytes(script_bytes)
                                                        : p2wsh_address_from_bytes(script_bytes);

        const auto pointer = address.get<int>("pointer");
        const auto multisig = output_script(subaccount, pointer);
        const auto sc_multisig
            = addr_type == address_type::p2sh ? p2sh_address_from_bytes(multisig) : p2wsh_address_from_bytes(multisig);

        GA_SDK_RUNTIME_ASSERT(sc == sc_multisig);

        address.set(addr_type_str, base58check_from_bytes(sc));
        return address;
    }

    template <typename T> balance session::session_impl::get_balance(T subaccount, size_t num_confs) const
    {
        balance b;
        wamp_call([&b](wamp_call_result result) { b = result.get().argument<msgpack::object>(0); },
            "com.greenaddress.txs.get_balance", subaccount, num_confs);
        return b;
    }

    available_currencies session::session_impl::get_available_currencies() const
    {
        available_currencies a;
        wamp_call([&a](wamp_call_result result) { a = result.get().argument<msgpack::object>(0); },
            "com.greenaddress.login.available_currencies");
        return a;
    }

    bool session::session_impl::is_rbf_enabled() const { return m_login_data.get<bool>("rbf"); }

    two_factor session::session_impl::get_twofactor_config()
    {
        two_factor f;
        wamp_call([&f](wamp_call_result result) { f = result.get().argument<msgpack::object>(0); },
            "com.greenaddress.twofactor.get_config");
        return f;
    }

    bool session::session_impl::set_twofactor(__attribute__((unused)) two_factor_type type, const std::string& code,
        __attribute__((unused)) const std::string& proxy_code)
    {
        wamp_call([](wamp_call_result result) { result.get(); }, "com.greenaddress.twofactor.enable_gauth", code,
            std::map<std::string, std::string>());
        return false;
    }

    pin_info session::session_impl::set_pin(
        const std::string& mnemonic, const std::string& pin, const std::string& device)
    {
        GA_SDK_RUNTIME_ASSERT(pin.length() >= 4);

        std::string pin_identifier;
        wamp_call(
            [&pin_identifier](wamp_call_result result) { pin_identifier = result.get().argument<std::string>(0); },
            "com.greenaddress.pin.set_pin_login", pin, device);

        secure_array<unsigned char, BIP39_SEED_LEN_512> seed;
        bip39_mnemonic_to_seed(mnemonic, nullptr, seed);
        const auto mnemonic_bytes = mnemonic_to_bytes(mnemonic, "en");
        const auto salt = get_random_bytes<16>();
        const auto password = get_pin_password(pin, pin_identifier);

        std::array<unsigned char, PBKDF2_HMAC_SHA512_LEN> key;
        pbkdf2_hmac_sha512(password, salt, 0, 2048, key);

        secure_array<unsigned char, BIP39_SEED_LEN_512 + BIP39_ENTROPY_LEN_256> data;
        init_container(data, seed, mnemonic_bytes);
        const auto iv = get_random_bytes<AES_BLOCK_LEN>();

        std::vector<unsigned char> encrypted(iv.size() + ((data.size() / AES_BLOCK_LEN) + 1) * AES_BLOCK_LEN);
        std::copy(iv.begin(), iv.end(), encrypted.begin());
        size_t written;
        GA_SDK_VERIFY(wally_aes_cbc(key.data(), AES_KEY_LEN_256, iv.data(), iv.size(), data.data(), data.size(),
            AES_FLAG_ENCRYPT, encrypted.data() + iv.size(), encrypted.size() - iv.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == encrypted.size() - iv.size());
        encrypted.resize(iv.size() + written);

        pin_info p;
        p.emplace("secret", hex_from_bytes(salt) + hex_from_bytes(encrypted));
        p.emplace("pin_identifier", pin_identifier);

        return p;
    }

    std::vector<unsigned char> session::session_impl::get_pin_password(
        const std::string& pin, const std::string& pin_identifier)
    {
        std::string password;
        wamp_call([&password](wamp_call_result result) { password = result.get().argument<std::string>(0); },
            "com.greenaddress.pin.get_password", pin, pin_identifier);

        return std::vector<unsigned char>(password.begin(), password.end());
    }

    login_data session::session_impl::login(const std::string& pin,
        const std::pair<std::string, std::string>& pin_identifier_and_secret, const std::string& user_agent)
    {
        const auto password = get_pin_password(pin, pin_identifier_and_secret.first);

        auto secret_bytes = bytes_from_hex(pin_identifier_and_secret.second);

        std::array<unsigned char, PBKDF2_HMAC_SHA512_LEN> key;
        pbkdf2_hmac_sha512(password, gsl::make_span(secret_bytes.data(), 16), 0, 2048, key);

        std::vector<unsigned char> plaintext(secret_bytes.size() - AES_BLOCK_LEN - 16);
        size_t written;
        GA_SDK_VERIFY(wally_aes_cbc(key.data(), AES_KEY_LEN_256, secret_bytes.data(), 16,
            secret_bytes.data() + 16 + AES_BLOCK_LEN, secret_bytes.size() - AES_BLOCK_LEN - 16, AES_FLAG_DECRYPT,
            plaintext.data(), plaintext.size(), &written));

        GA_SDK_RUNTIME_ASSERT(written <= plaintext.size() && (plaintext.size() - written <= AES_BLOCK_LEN));

        const auto mnemonic = mnemonic_from_bytes(plaintext.data() + BIP39_SEED_LEN_512, BIP39_ENTROPY_LEN_256, "en");

        return login(mnemonic, user_agent);
    }

    bool session::session_impl::add_address_book_entry(
        const std::string& address, const std::string& name, size_t rating)
    {
        bool r{ false };
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.addressbook.add_entry", address, name, rating);
        return r;
    }

    bool session::session_impl::edit_address_book_entry(
        const std::string& address, const std::string& name, size_t rating)
    {
        bool r{ false };
        wamp_call([&r](wamp_call_result result) { r = result.get().argument<bool>(0); },
            "com.greenaddress.addressbook.edit_entry", address, name, rating);
        return r;
    }

    void session::session_impl::delete_address_book_entry(const std::string& address)
    {
        wamp_call([](wamp_call_result result) { result.get(); }, "com.greenaddress.addressbook.delete_entry", address);
    }

    // Add a UTXO to a transaction. Returns the amount added
    amount session::session_impl::add_utxo(const wally_tx_ptr& tx, const utxo& u) const
    {
        const auto txhash = u.get<std::string>("txhash");
        const auto index = u.get<uint32_t>("pt_idx");
        const uint32_t sequence = is_rbf_enabled() ? 0xFFFFFFFD : 0xFFFFFFFE;
        const auto subaccount = u.get_with_default<uint32_t>("subaccount", 0);
        const auto pointer = u.get_with_default<uint32_t>("pubkey_pointer", u.get<uint32_t>("pointer"));
        const auto type = script_type(u.get<uint32_t>("script_type"));

        // FIXME: As we are only adding dummy scripts/witness data for sizing
        //        purposes, we don't need to actually call output_script here.
        //        Instead, use fixed length empty arrays for 2of2 and 2of3.
        //        When we sign the input we create the scripts with the correct
        //        signatures and overwite these values.
        const auto prevout_script = output_script(subaccount, pointer);
        wally_tx_witness_stack_ptr wit;

        if (type == script_type::p2sh_p2wsh_fortified_out) {
            wit = tx_witness_stack_init(4);
            tx_witness_stack_add_dummy(wit, WALLY_TX_DUMMY_NULL);
            tx_witness_stack_add_dummy(wit, WALLY_TX_DUMMY_SIG);
            tx_witness_stack_add_dummy(wit, WALLY_TX_DUMMY_SIG);
            tx_witness_stack_add(wit, prevout_script);
        }

        tx_add_raw_input(tx, bytes_from_hex_rev(txhash), index, sequence,
            wit ? DUMMY_WITNESS_SCRIPT : dummy_input_script(prevout_script), wit, 0);

        return amount{ std::stoull(u.get<std::string>("value"), nullptr, 10) };
    }

    void session::session_impl::sign_input(const wally_tx_ptr& tx, uint32_t index, const utxo& u) const
    {
        const auto txhash = u.get<std::string>("txhash");
        const auto subaccount = u.get_with_default<uint32_t>("subaccount", 0);
        const auto pointer = u.get_with_default<uint32_t>("pubkey_pointer", u.get<uint32_t>("pointer"));
        const amount satoshi{ std::stoull(u.get<std::string>("value"), nullptr, 10) };
        const auto type = script_type(u.get<uint32_t>("script_type"));

        const auto prevout_script = output_script(subaccount, pointer);

        std::array<unsigned char, SHA256_LEN> tx_hash;
        const uint32_t flags = type == script_type::p2sh_p2wsh_fortified_out ? WALLY_TX_FLAG_USE_WITNESS : 0;
        tx_get_btc_signature_hash(tx, index, prevout_script, satoshi.value(), WALLY_SIGHASH_ALL, flags, tx_hash);

        secure_array<unsigned char, EC_PRIVATE_KEY_LEN> client_priv_key;
        derive_private_key(m_master_key, std::array<uint32_t, 2>{ { 1, pointer } }, client_priv_key);

        std::array<unsigned char, EC_SIGNATURE_LEN> user_sig;
        ec_sig_from_bytes(client_priv_key, tx_hash, EC_FLAG_ECDSA, user_sig);

        if (type == script_type::p2sh_p2wsh_fortified_out) {
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
        const amount min_fee_rate{ m_login_data.get<amount::value_type>("min_fee") };
        const amount rate = fee_rate < min_fee_rate ? min_fee_rate : fee_rate;

        size_t vsize;
        tx_get_vsize(tx, &vsize);

        const auto fee = static_cast<double>(vsize) * rate.value() / 1000.0;
        const auto rounded_fee = static_cast<amount::value_type>(std::ceil(fee));

        return amount{ rounded_fee };
    }

    std::string session::session_impl::make_raw_tx(const std::vector<std::pair<std::string, amount>>& address_amount,
        const std::vector<utxo>& utxos, amount fee_rate, bool send_all)
    {
        GA_SDK_RUNTIME_ASSERT(!address_amount.empty() && !utxos.empty() && (!send_all || address_amount.size() == 1));

        auto tx = tx_init(m_block_height, utxos.size());

        amount total, fee;

        for (auto&& u : utxos) {
            if (!send_all && total >= address_amount[0].second) {
                break;
            }
            total += add_utxo(tx, u);
        }

        tx_add_raw_output(tx, address_amount[0].second.value(), output_script_for_address(address_amount[0].first), 0);

        bool have_change = false;
        const amount dust_threshold = get_dust_threshold();

        for (;;) {
            fee = get_tx_fee(tx, fee_rate);
            const amount min_change = have_change ? amount() : dust_threshold;
            const amount am = address_amount[0].second + fee + min_change;
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

            // FIXME: Only get segwit change if segwit is enabled
            const auto change_address = get_receive_address(address_type::p2wsh, 0);
            const auto change_output_script = output_script_for_address(change_address.get<std::string>("p2wsh"));
            tx_add_raw_output(tx, 0, change_output_script, 0);
            have_change = true;
        }

        if (have_change) {
            tx->outputs[1].satoshi = (total - address_amount[0].second - fee).value();
            // FIXME: Randomize change output (swap output 0 and 1 with 50% probability)
        }

        auto ub = utxos.begin();
        for (uint32_t i = 0; i < tx->num_inputs; ++i) {
            sign_input(tx, i, *ub++);
        }

        return hex_from_bytes(tx_to_bytes(tx));
    }

    void session::session_impl::send(const std::string& tx_hex)
    {
        wamp_call([](boost::future<autobahn::wamp_call_result> result) { result.get(); },
            "com.greenaddress.vault.send_raw_tx", tx_hex);
    }

    void session::session_impl::send(const std::vector<std::pair<std::string, amount>>& address_amount,
        const std::vector<utxo>& utxos, amount fee_rate, bool send_all)
    {
        send(make_raw_tx(address_amount, utxos, fee_rate, send_all));
    }

    void session::session_impl::send(
        const std::vector<std::pair<std::string, amount>>& address_amount, amount fee_rate, bool send_all)
    {
        const auto utxos = get_utxos(1, 0);

        std::vector<utxo> utxos_in_use;
        for (auto&& u : utxos) {
            utxos_in_use.emplace_back(u);
        }

        send(address_amount, utxos_in_use, fee_rate, send_all);
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

    login_data session::login(const std::string& mnemonic, const std::string& user_agent)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->login(mnemonic, user_agent); });
    }

    login_data session::login(const std::string& pin,
        const std::pair<std::string, std::string>& pin_identifier_and_secret, const std::string& user_agent)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->login(pin, pin_identifier_and_secret, user_agent); });
    }

    login_data session::login_watch_only(
        const std::string& username, const std::string& password, const std::string& user_agent)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->login_watch_only(username, password, user_agent); });
    }

    bool session::set_watch_only(const std::string& username, const std::string& password)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->set_watch_only(username, password); });
    }

    bool session::remove_account()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->remove_account(); });
    }

    std::pair<std::string, std::string> session::create_subaccount(
        subaccount_type type, const std::string& name, const std::string& xpub)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->create_subaccount(type, name, xpub); });
    }

    void session::change_settings_helper(settings key, const std::map<int, int>& args)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->change_settings_helper(key, args); });
    }

    tx_list session::get_tx_list(const std::pair<std::time_t, std::time_t>& date_range, size_t subaccount,
        tx_list_sort_by sort_by, size_t page_id, const std::string& query)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_tx_list(date_range, subaccount, sort_by, page_id, query); });
    }

    void session::subscribe(const std::string& topic, std::function<void(const std::string& output)> callback)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->subscribe(topic, callback); });
    }

    receive_address session::get_receive_address(address_type addr_type, size_t subaccount)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_receive_address(addr_type, subaccount); });
    }

    std::vector<subaccount> session::get_subaccounts()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_subaccounts(); });
    }

    balance session::get_balance_for_subaccount(size_t subaccount, size_t num_confs)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_balance(subaccount, num_confs); });
    }

    balance session::get_balance(size_t num_confs)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_balance("all", num_confs); });
    }

    available_currencies session::get_available_currencies()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_available_currencies(); });
    }

    bool session::is_rbf_enabled()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->is_rbf_enabled(); });
    }

    two_factor session::get_twofactor_config()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_twofactor_config(); });
    }

    bool session::set_twofactor(two_factor_type type, const std::string& code, const std::string& proxy_code)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->set_twofactor(type, code, proxy_code); });
    }

    pin_info session::set_pin(const std::string& mnemonic, const std::string& pin, const std::string& device)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->set_pin(mnemonic, pin, device); });
    }

    bool session::add_address_book_entry(const std::string& address, const std::string& name, size_t rating)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->add_address_book_entry(address, name, rating); });
    }

    bool session::edit_address_book_entry(const std::string& address, const std::string& name, size_t rating)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->edit_address_book_entry(address, name, rating); });
    }

    void session::delete_address_book_entry(const std::string& address)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->delete_address_book_entry(address); });
    }

    utxo_set session::get_utxos(size_t num_confs, size_t subaccount)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_utxos(num_confs, subaccount); });
    }

    std::string session::make_raw_tx(const std::vector<std::pair<std::string, amount>>& address_amount,
        const std::vector<utxo>& utxos, amount fee_rate, bool send_all)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->make_raw_tx(address_amount, utxos, fee_rate, send_all); });
    }

    void session::send(const std::string& tx_hex)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->send(tx_hex); });
    }

    void session::send(const std::vector<std::pair<std::string, amount>>& address_amount,
        const std::vector<utxo>& utxos, amount fee_rate, bool send_all)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->send(address_amount, utxos, fee_rate, send_all); });
    }

    void session::send(
        const std::vector<std::pair<std::string, amount>>& address_amount, amount fee_rate, bool send_all)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->send(address_amount, fee_rate, send_all); });
    }
}
}
