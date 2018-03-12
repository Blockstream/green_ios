#include <algorithm>
#include <array>
#include <ctime>
#include <thread>
#include <type_traits>
#include <unordered_map>
#include <vector>

#include <boost/algorithm/string/predicate.hpp>
#include <boost/multiprecision/cpp_int.hpp>
#include <boost/variant.hpp>

#include <wally.hpp>

#include "assertion.hpp"
#include "autobahn_wrapper.hpp"
#include "exception.hpp"
#include "memory.hpp"
#include "session.hpp"
#include "transaction_utils.hpp"

namespace ga {
namespace sdk {
    using client = websocketpp::client<websocketpp::config::asio_client>;
    using client_tls = websocketpp::client<websocketpp::config::asio_tls_client>;
    using transport = autobahn::wamp_websocketpp_websocket_transport<websocketpp::config::asio_client>;
    using transport_tls = autobahn::wamp_websocketpp_websocket_transport<websocketpp::config::asio_tls_client>;
    using context_ptr = websocketpp::lib::shared_ptr<boost::asio::ssl::context>;
    using wamp_call_result = boost::future<autobahn::wamp_call_result>;

    static const std::string DEFAULT_REALM("realm1");
    static const std::string DEFAULT_USER_AGENT("[v2,sw]");
    static const unsigned char GA_LOGIN_NONCE[30] = { 'G', 'r', 'e', 'e', 'n', 'A', 'd', 'd', 'r', 'e', 's', 's', '.',
        'i', 't', ' ', 'H', 'D', ' ', 'w', 'a', 'l', 'l', 'e', 't', ' ', 'p', 'a', 't', 'h' };

    namespace {
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

        std::vector<unsigned char> tx_to_bytes(const wally_tx_ptr& tx)
        {
            std::vector<unsigned char> bytes(1024);
            bool complete = false;

            while (!complete) {
                size_t written;
                GA_SDK_VERIFY(wally::tx_to_bytes(tx, WALLY_TX_FLAG_USE_WITNESS, &written, bytes));
                complete = written <= bytes.size();
                bytes.resize(written);
            }
            return bytes;
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
        explicit session_impl(network_parameters params, bool debug)
            : m_controller(m_io)
            , m_params(std::move(params))
            , m_block_height(0)
            , m_master_key(nullptr)
            , m_debug(debug)
        {
            connect_with_tls() ? make_client<client_tls>() : make_client<client>();
        }

        ~session_impl() { m_io.stop(); }

        void connect();
        void register_user(const std::string& mnemonic, const std::string& user_agent);
        login_data login(const std::string& mnemonic, const std::string& user_agent);
        login_data login_watch_only(
            const std::string& username, const std::string& password, const std::string& user_agent);
        bool set_watch_only(const std::string& username, const std::string& password);
        bool remove_account();

        login_data login(const std::string& pin, const std::pair<std::string, std::string>& pin_identifier_and_secret,
            const std::string& user_agent = std::string());
        void change_settings_helper(settings key, const std::map<int, int>& args);

        tx_list get_tx_list(const std::pair<std::time_t, std::time_t>& date_range, size_t subaccount,
            tx_list_sort_by sort_by, size_t page_id, const std::string& query);
        void subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler);
        void subscribe(const std::string& topic, std::function<void(const std::string& output)> callback);
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
        wally_string_ptr make_raw_tx(const std::vector<std::pair<std::string, amount>>& address_amount,
            const std::vector<utxo>& utxos, amount fee_rate, bool send_all);
        void send(const wally_string_ptr& raw_tx);
        void send(const std::vector<std::pair<std::string, amount>>& address_amount, const std::vector<utxo>& utxos,
            amount fee_rate, bool send_all);
        void send(const std::vector<std::pair<std::string, amount>>& address_amount, amount fee_rate, bool send_all);

    private:
        static std::pair<wally_string_ptr, wally_string_ptr> sign_challenge(
            const wally_ext_key_ptr& master_key, const std::string& challenge);

        bool connect_with_tls() const { return boost::algorithm::starts_with(m_params.gait_wamp_url(), "wss://"); }

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

            m_transport = std::make_shared<T>(*boost::get<client_type>(m_client), m_params.gait_wamp_url(), m_debug),
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

        std::vector<unsigned char> get_pin_password(const std::string& pin, const std::string& pin_identifier);

        amount get_dust_threshold() const;
        std::string get_raw_output(const std::string& txhash) const;
        secure_vector<unsigned char> output_script(uint32_t subaccount, uint32_t pointer) const;
        wally_tx_input_ptr add_utxo(const utxo& u) const;
        wally_tx_input_ptr sign_input(const wally_tx_ptr& tx, uint32_t index, const utxo& u) const;
        amount get_tx_fee(const wally_tx_ptr& tx, amount fee_rate);

    private:
        uint32_t get_bip32_version() const
        {
            return m_params.main_net() ? BIP32_VER_MAIN_PRIVATE : BIP32_VER_TEST_PRIVATE;
        }

        boost::asio::io_service m_io;
        boost::variant<std::unique_ptr<client>, std::unique_ptr<client_tls>> m_client;
        boost::variant<std::shared_ptr<transport>, std::shared_ptr<transport_tls>> m_transport;
        std::shared_ptr<autobahn::wamp_session> m_session;

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

    std::pair<wally_string_ptr, wally_string_ptr> session::session_impl::sign_challenge(
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
        GA_SDK_VERIFY(wally::ec_sig_from_bytes(login_priv_key, challenge_hash, EC_FLAG_ECDSA, sig));

        std::array<unsigned char, EC_SIGNATURE_DER_MAX_LEN> der;
        size_t der_written;
        GA_SDK_VERIFY(wally::ec_sig_to_der(sig, &der_written, der));

        return { hex_from_bytes(der.data(), der_written), hex_from_bytes(path_bytes) };
    }

    void session::session_impl::register_user(const std::string& mnemonic, const std::string& user_agent)
    {
        secure_array<unsigned char, BIP39_SEED_LEN_512> seed;
        size_t written;
        GA_SDK_VERIFY(bip39_mnemonic_to_seed(mnemonic.data(), NULL, seed.data(), seed.size(), &written));

        ext_key master;
        GA_SDK_VERIFY(wally::bip32_key_from_seed(seed, get_bip32_version(), BIP32_FLAG_SKIP_HASH, &master));
        // Since we don't use the private key or seed further, wipe them immediately
        GA_SDK_VERIFY(wally::clear(master.priv_key, sizeof(master.priv_key)));
        GA_SDK_VERIFY(wally::clear(seed));

        std::array<unsigned char, sizeof(master.chain_code) + sizeof(master.pub_key)> path_data;
        init_container(path_data, make_bytes_view(master.chain_code), make_bytes_view(master.pub_key));

        std::array<unsigned char, HMAC_SHA512_LEN> path;
        GA_SDK_VERIFY(wally::hmac_sha512(make_bytes_view(GA_LOGIN_NONCE), path_data, path));

        auto pub_key = hex_from_bytes(make_bytes_view(master.pub_key));
        auto chain_code = hex_from_bytes(make_bytes_view(master.chain_code));
        auto hex_path = hex_from_bytes(path);

        auto register_arguments = std::make_tuple(
            pub_key.get(), chain_code.get(), DEFAULT_USER_AGENT + user_agent + "_ga_sdk", hex_path.get());
        auto fn
            = m_session->call("com.greenaddress.login.register", register_arguments).then([](wamp_call_result result) {
                  GA_SDK_RUNTIME_ASSERT(result.get().argument<bool>(0));
              });
        fn.get();
    }

    login_data session::session_impl::login(const std::string& mnemonic, const std::string& user_agent)
    {
        secure_array<unsigned char, BIP39_SEED_LEN_512> seed;
        size_t written;
        GA_SDK_VERIFY(bip39_mnemonic_to_seed(mnemonic.data(), NULL, seed.data(), seed.size(), &written));

        // FIXME: Allocate m_master_key in mlocked memory and pass it
        ext_key* p;
        GA_SDK_VERIFY(wally::bip32_key_from_seed_alloc(seed, get_bip32_version(), 0, &p));

        m_master_key = wally_ext_key_ptr(p);

        unsigned char btc_ver[1] = { m_params.btc_version() };
        std::array<unsigned char, sizeof(btc_ver) + sizeof(m_master_key->hash160)> vpkh;
        init_container(vpkh, make_bytes_view(btc_ver), make_bytes_view(m_master_key->hash160));

        char* q;
        GA_SDK_VERIFY(wally::base58_from_bytes(vpkh, BASE58_FLAG_CHECKSUM, &q));
        wally_string_ptr base58_pkh(q);

        auto challenge_arguments = std::make_tuple(base58_pkh.get());
        std::string challenge;
        auto fn
            = m_session->call("com.greenaddress.login.get_challenge", challenge_arguments)
                  .then([&challenge](wamp_call_result result) { challenge = result.get().argument<std::string>(0); });

        fn.get();

        auto hexder_path = sign_challenge(m_master_key, challenge);

        auto authenticate_arguments = std::make_tuple(hexder_path.first.get(), false, hexder_path.second.get(),
            std::string("fake_dev_id"), DEFAULT_USER_AGENT + user_agent + "_ga_sdk");
        fn = m_session->call("com.greenaddress.login.authenticate", authenticate_arguments)
                 .then([this](wamp_call_result result) { m_login_data = result.get().argument<msgpack::object>(0); });

        fn.get();

        m_block_height = m_login_data.get<size_t>("block_height");
        subscribe("com.greenaddress.blocks", [this](const autobahn::wamp_event& event) {
            block_event block_ev;
            block_ev = event.argument<msgpack::object>(0);
            const size_t count = block_ev.get<size_t>("count");
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
        auto fn
            = m_session
                  ->call("com.greenaddress.login.watch_only_v2",
                      std::make_tuple("custom",
                          std::map<std::string, std::string>({ { "username", username }, { "password", password } }),
                          DEFAULT_USER_AGENT + user_agent + "_ga_sdk"))
                  .then([this](wamp_call_result result) { m_login_data = result.get().argument<msgpack::object>(0); });

        fn.get();

        return m_login_data;
    }

    bool session::session_impl::set_watch_only(const std::string& username, const std::string& password)
    {
        bool r;
        auto fn = m_session->call("com.greenaddress.addressbook.sync_custom", std::make_tuple(username, password))
                      .then([&r](wamp_call_result result) { r = result.get().argument<bool>(0); });

        fn.get();

        return r;
    }

    bool session::session_impl::remove_account()
    {
        bool r;
        auto fn
            = m_session
                  ->call("com.greenaddress.login.remove_account", std::make_tuple(std::map<std::string, std::string>()))
                  .then([&r](wamp_call_result result) { r = result.get().argument<bool>(0); });

        fn.get();

        return r;
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
            auto change_settings_arguments = std::make_tuple(key_str, arg);
            auto fn = m_session->call("com.greenaddress.login.change_settings", change_settings_arguments)
                          .then([](wamp_call_result result) { GA_SDK_RUNTIME_ASSERT(result.get().argument<bool>(0)); });

            fn.get();
        };

        if (key == settings::tx_limits) {
            change_settings(to_args({ "is_fiat", "per_tx", "total" }));
        } else {
            GA_SDK_RUNTIME_ASSERT(args.size());
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

            if (!date_range.first && !date_range.second) {
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
        const auto get_tx_list_arguments = std::make_tuple(page_id, query, sort_by_str(), date_range_str(), subaccount);
        auto fn = m_session->call("com.greenaddress.txs.get_list_v2", get_tx_list_arguments)
                      .then([&txs](wamp_call_result result) { txs = result.get().argument<msgpack::object>(0); });

        fn.get();

        return txs;
    }

    void session::session_impl::subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler)
    {
        auto subscribe_future = m_session->subscribe(topic, handler, autobahn::wamp_subscribe_options("exact"))
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
        return { m_login_data.get<amount::value_type>("dust") };
    }

    std::string session::session_impl::get_raw_output(const std::string& txhash) const
    {
        std::string raw_output;
        auto fn
            = m_session->call("com.greenaddress.txs.get_raw_output", std::make_tuple(txhash))
                  .then([&raw_output](wamp_call_result result) { raw_output = result.get().argument<std::string>(0); });

        fn.get();

        return raw_output;
    }

    secure_vector<unsigned char> session::session_impl::output_script(uint32_t subaccount, uint32_t pointer) const
    {
        GA_SDK_RUNTIME_ASSERT(!m_params.deposit_chain_code().empty());
        GA_SDK_RUNTIME_ASSERT(!m_params.deposit_pub_key().empty());
        return ga::sdk::output_script(m_master_key, m_params.deposit_chain_code(), m_params.deposit_pub_key(),
            m_login_data.get<std::string>("gait_path"), subaccount, pointer, m_params.main_net());
    }

    utxo_set session::session_impl::get_utxos(size_t num_confs, size_t subaccount)
    {
        utxo_set unspent;
        auto fn
            = m_session
                  ->call("com.greenaddress.txs.get_all_unspent_outputs", std::make_tuple(num_confs, subaccount, "any"))
                  .then([&unspent](wamp_call_result result) {
                      const auto r = result.get();
                      if (r.number_of_arguments()) {
                          unspent = r.argument<msgpack::object>(0);
                      }
                  });

        fn.get();

        return unspent;
    }

    receive_address session::session_impl::get_receive_address(address_type addr_type, size_t subaccount) const
    {
        const std::string addr_type_str = addr_type == address_type::p2sh ? "p2sh" : "p2wsh";

        receive_address address;
        auto fn
            = m_session->call("com.greenaddress.vault.fund", std::make_tuple(subaccount, true, addr_type_str))
                  .then([&address](wamp_call_result result) { address = result.get().argument<msgpack::object>(0); });

        fn.get();

        const auto script_bytes = bytes_from_hex(address.get<std::string>("script"));

        const auto sc = addr_type == address_type::p2sh ? p2sh_address_from_bytes(script_bytes)
                                                        : p2wsh_address_from_bytes(script_bytes);

        const auto pointer = address.get<int>("pointer");
        const auto multisig = output_script(subaccount, pointer);
        const auto sc_multisig
            = addr_type == address_type::p2sh ? p2sh_address_from_bytes(multisig) : p2wsh_address_from_bytes(multisig);

        GA_SDK_RUNTIME_ASSERT(sc == sc_multisig);

        char* q;
        GA_SDK_VERIFY(wally::base58_from_bytes(sc, BASE58_FLAG_CHECKSUM, &q));
        wally_string_ptr base58_pkh(q);

        address.set(addr_type_str, std::string(q));

        return address;
    }

    template <typename T> balance session::session_impl::get_balance(T subaccount, size_t num_confs) const
    {
        balance b;

        auto fn = m_session->call("com.greenaddress.txs.get_balance", std::make_tuple(subaccount, num_confs))
                      .then([&b](wamp_call_result result) { b = result.get().argument<msgpack::object>(0); });

        fn.get();

        return b;
    }

    available_currencies session::session_impl::get_available_currencies() const
    {
        available_currencies a;

        auto fn = m_session->call("com.greenaddress.login.available_currencies", std::make_tuple())
                      .then([&a](wamp_call_result result) { a = result.get().argument<msgpack::object>(0); });

        fn.get();

        return a;
    }

    bool session::session_impl::is_rbf_enabled() const { return m_login_data.get<bool>("rbf"); }

    two_factor session::session_impl::get_twofactor_config()
    {
        two_factor f;

        auto fn = m_session->call("com.greenaddress.twofactor.get_config", std::make_tuple())
                      .then([&f](wamp_call_result result) { f = result.get().argument<msgpack::object>(0); });

        fn.get();

        return f;
    }

    bool session::session_impl::set_twofactor(__attribute__((unused)) two_factor_type type, const std::string& code,
        __attribute__((unused)) const std::string& proxy_code)
    {
        auto fn = m_session
                      ->call("com.greenaddress.twofactor.enable_gauth",
                          // std::make_tuple(code, std::map<std::string, std::string>{ { "proxy", proxy_code } }))
                          std::make_tuple(code, std::map<std::string, std::string>()))
                      .then([](wamp_call_result result) { result.get(); });

        fn.get();

        return false;
    }

    pin_info session::session_impl::set_pin(
        const std::string& mnemonic, const std::string& pin, const std::string& device)
    {
        GA_SDK_RUNTIME_ASSERT(pin.length() >= 4);

        std::string pin_identifier;

        auto fn = m_session->call("com.greenaddress.pin.set_pin_login", std::make_tuple(pin, device))
                      .then([&pin_identifier](
                          wamp_call_result result) { pin_identifier = result.get().argument<std::string>(0); });

        fn.get();

        const auto password = get_pin_password(pin, pin_identifier);

        auto salt = get_random_bytes<16>();
        const auto salt_hex = hex_from_bytes(salt);

        std::array<unsigned char, BIP39_SEED_LEN_512> seed;
        size_t written;
        GA_SDK_VERIFY(bip39_mnemonic_to_seed(mnemonic.data(), NULL, seed.data(), seed.size(), &written));
        const auto seed_hex = hex_from_bytes(seed.data(), written);
        const auto mnemonic_bytes = mnemonic_to_bytes(mnemonic, "en");
        const auto mnemonic_hex = hex_from_bytes(mnemonic_bytes);

        std::array<unsigned char, PBKDF2_HMAC_SHA512_LEN> key;
        GA_SDK_VERIFY(wally::pbkdf2_hmac_sha512(password, salt, 0, 2048, key));

        std::array<unsigned char, BIP39_SEED_LEN_512 + BIP39_ENTROPY_LEN_256> data;
        init_container(data, seed, mnemonic_bytes);

        const auto iv = get_random_bytes<AES_BLOCK_LEN>();

        std::vector<unsigned char> encrypted(iv.size() + ((data.size() / AES_BLOCK_LEN) + 1) * AES_BLOCK_LEN);
        std::copy(iv.begin(), iv.end(), encrypted.begin());
        GA_SDK_VERIFY(wally_aes_cbc(key.data(), AES_KEY_LEN_256, iv.data(), iv.size(), data.data(), data.size(),
            AES_FLAG_ENCRYPT, encrypted.data() + iv.size(), encrypted.size() - iv.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == encrypted.size() - iv.size());

        const auto encrypted_hex = hex_from_bytes(encrypted.data(), iv.size() + written);

        pin_info p;
        p.emplace("secret", std::string(salt_hex.get()) + std::string(encrypted_hex.get()));
        p.emplace("pin_identifier", pin_identifier);

        return p;
    }

    std::vector<unsigned char> session::session_impl::get_pin_password(
        const std::string& pin, const std::string& pin_identifier)
    {
        std::string password;

        auto fn = m_session->call("com.greenaddress.pin.get_password", std::make_tuple(pin, pin_identifier))
                      .then([&password](wamp_call_result result) { password = result.get().argument<std::string>(0); });

        fn.get();

        return std::vector<unsigned char>(password.begin(), password.end());
    }

    login_data session::session_impl::login(const std::string& pin,
        const std::pair<std::string, std::string>& pin_identifier_and_secret, const std::string& user_agent)
    {
        const auto password = get_pin_password(pin, pin_identifier_and_secret.first);

        auto secret_bytes = bytes_from_hex(pin_identifier_and_secret.second);

        std::array<unsigned char, PBKDF2_HMAC_SHA512_LEN> key;
        GA_SDK_VERIFY(wally_pbkdf2_hmac_sha512(
            password.data(), password.size(), secret_bytes.data(), 16, 0, 2048, key.data(), key.size()));

        std::vector<unsigned char> plaintext(secret_bytes.size() - AES_BLOCK_LEN - 16);
        size_t written;
        GA_SDK_VERIFY(wally_aes_cbc(key.data(), AES_KEY_LEN_256, secret_bytes.data(), 16,
            secret_bytes.data() + 16 + AES_BLOCK_LEN, secret_bytes.size() - AES_BLOCK_LEN - 16, AES_FLAG_DECRYPT,
            plaintext.data(), plaintext.size(), &written));

        GA_SDK_RUNTIME_ASSERT(written <= plaintext.size() && (plaintext.size() - written <= AES_BLOCK_LEN));

        const auto mnemonic = mnemonic_from_bytes(plaintext.data() + BIP39_SEED_LEN_512, BIP39_ENTROPY_LEN_256, "en");

        return login(std::string(mnemonic.get()), user_agent);
    }

    bool session::session_impl::add_address_book_entry(
        const std::string& address, const std::string& name, size_t rating)
    {
        bool r{ false };

        auto fn = m_session->call("com.greenaddress.addressbook.add_entry", std::make_tuple(address, name, rating))
                      .then([&r](wamp_call_result result) { r = result.get().argument<bool>(0); });

        fn.get();

        return r;
    }

    bool session::session_impl::edit_address_book_entry(
        const std::string& address, const std::string& name, size_t rating)
    {
        bool r{ false };

        auto fn = m_session->call("com.greenaddress.addressbook.edit_entry", std::make_tuple(address, name, rating))
                      .then([&r](wamp_call_result result) { r = result.get().argument<bool>(0); });

        fn.get();

        return r;
    }

    void session::session_impl::delete_address_book_entry(const std::string& address)
    {
        auto fn = m_session->call("com.greenaddress.addressbook.delete_entry", std::make_tuple(address))
                      .then([](wamp_call_result result) { result.get(); });

        fn.get();
    }

    wally_tx_input_ptr session::session_impl::add_utxo(const utxo& u) const
    {
        const std::string txhash = u.get<std::string>("txhash");
        const uint32_t subaccount = u.get_with_default<uint32_t>("subaccount", 0);
        const uint32_t pointer = u.get_with_default<uint32_t>("pubkey_pointer", u.get<uint32_t>("pointer"));
        const uint32_t index = u.get<uint32_t>("pt_idx");
        const auto type = script_type(u.get<uint32_t>("script_type"));

        const auto outscript = output_script(subaccount, pointer);

        std::array<std::array<unsigned char, EC_SIGNATURE_DER_MAX_LEN + 1>, 2> sigs{ { { { 0 } }, { { 0 } } } };

        const auto txhash_bytes = bytes_from_hex(txhash);
        const auto txhash_bytes_rev = std::vector<unsigned char>(txhash_bytes.rbegin(), txhash_bytes.rend());
        struct wally_tx_input* tx_in;

        if (type == script_type::p2sh_p2wsh_fortified_out) {
            struct wally_tx_witness_stack* witness_stack;
            GA_SDK_VERIFY(wally::tx_witness_stack_init_alloc(1, 4, &witness_stack));
            wally_tx_witness_stack_ptr witness{ witness_stack };
            GA_SDK_VERIFY(wally::tx_witness_stack_add(witness_stack, sigs[0]));
            GA_SDK_VERIFY(wally::tx_witness_stack_add(witness_stack, sigs[1]));
            GA_SDK_VERIFY(wally::tx_witness_stack_add(witness_stack, outscript));
            const auto script_bytes = witness_script(outscript);
            GA_SDK_VERIFY(wally::tx_input_init_alloc(txhash_bytes_rev, index,
                is_rbf_enabled() ? 0xFFFFFFFD : 0xFFFFFFFE, script_bytes, witness_stack, &tx_in));
        } else {
            const auto in_script
                = input_script(sigs, { { EC_SIGNATURE_DER_MAX_LEN + 1, EC_SIGNATURE_DER_MAX_LEN + 1 } }, 2, outscript);
            GA_SDK_VERIFY(wally::tx_input_init_alloc(
                txhash_bytes_rev, index, is_rbf_enabled() ? 0xFFFFFFFD : 0xFFFFFFFE, in_script, nullptr, &tx_in));
        }

        return wally_tx_input_ptr{ tx_in };
    }

    wally_tx_input_ptr session::session_impl::sign_input(const wally_tx_ptr& tx, uint32_t index, const utxo& u) const
    {
        const std::string txhash = u.get<std::string>("txhash");
        const uint32_t subaccount = u.get_with_default<uint32_t>("subaccount", 0);
        const uint32_t pointer = u.get_with_default<uint32_t>("pubkey_pointer", u.get<uint32_t>("pointer"));
        const uint32_t pt_idx = u.get<uint32_t>("pt_idx");
        const amount satoshi = std::stoull(u.get<std::string>("value").c_str(), nullptr, 10);
        const auto type = script_type(u.get<uint32_t>("script_type"));

        const auto txhash_bytes = bytes_from_hex(txhash);
        const auto txhash_bytes_rev = std::vector<unsigned char>(txhash_bytes.rbegin(), txhash_bytes.rend());

        const auto out_script = output_script(subaccount, pointer);

        std::array<unsigned char, SHA256_LEN> tx_hash;
        const uint32_t flags = type == script_type::p2sh_p2wsh_fortified_out ? WALLY_TX_FLAG_USE_WITNESS : 0;
        GA_SDK_VERIFY(wally::tx_get_btc_signature_hash(
            tx, index, out_script, satoshi.value(), WALLY_SIGHASH_ALL, flags, tx_hash));

        secure_array<unsigned char, EC_PRIVATE_KEY_LEN> client_priv_key;
        derive_private_key(m_master_key, std::array<uint32_t, 2>{ { 1, pointer } }, client_priv_key);
        std::array<unsigned char, EC_SIGNATURE_LEN> sig;
        GA_SDK_VERIFY(wally::ec_sig_from_bytes(client_priv_key, tx_hash, EC_FLAG_ECDSA, sig));

        std::array<std::array<unsigned char, EC_SIGNATURE_DER_MAX_LEN + 1>, 2> sigs{ { { { 0 } }, { { 0 } } } };
        size_t der_written;
        GA_SDK_VERIFY(wally::ec_sig_to_der(sig, &der_written, sigs[0]));

        sigs[0][der_written] = WALLY_SIGHASH_ALL;

        struct wally_tx_input* tx_in;
        if (type == script_type::p2sh_p2wsh_fortified_out) {
            struct wally_tx_witness_stack* witness_stack{ nullptr };
            GA_SDK_VERIFY(wally_tx_witness_stack_init_alloc(0, 1, &witness_stack));
            wally_tx_witness_stack_ptr witness{ witness_stack };
            GA_SDK_VERIFY(wally_tx_witness_stack_add(witness_stack, sigs[0].data(), der_written + 1));
            const auto script_bytes = witness_script(out_script);
            GA_SDK_VERIFY(wally::tx_input_init_alloc(txhash_bytes_rev, pt_idx,
                is_rbf_enabled() ? 0xFFFFFFFD : 0xFFFFFFFE, script_bytes, witness_stack, &tx_in));
        } else {
            const auto in_script = input_script(sigs, { { der_written + 1, 0 } }, 1, out_script);
            GA_SDK_VERIFY(wally::tx_input_init_alloc(
                txhash_bytes_rev, pt_idx, is_rbf_enabled() ? 0xFFFFFFFD : 0xFFFFFFFE, in_script, nullptr, &tx_in));
        }

        return wally_tx_input_ptr{ tx_in };
    }

    amount session::session_impl::get_tx_fee(const wally_tx_ptr& tx, amount fee_rate)
    {
        const amount min_fee_rate = m_login_data.get<long>("min_fee");
        const amount rate = fee_rate < min_fee_rate ? min_fee_rate : fee_rate;

        size_t vsize;
        GA_SDK_VERIFY(wally::tx_get_vsize(tx, &vsize));

        const double fee = static_cast<double>(vsize) * rate.value() / 1000.0;
        const long rounded_fee = static_cast<long>(std::ceil(fee));

        return rounded_fee;
    }

    namespace {
        wally_tx_output_ptr create_tx_output(amount v, const unsigned char* script, size_t size)
        {
            struct wally_tx_output* tx_out;
            GA_SDK_VERIFY(wally_tx_output_init_alloc(v.value(), script, size, &tx_out));
            return wally_tx_output_ptr{ tx_out };
        }
    }

    wally_string_ptr session::session_impl::make_raw_tx(
        const std::vector<std::pair<std::string, amount>>& address_amount, const std::vector<utxo>& utxos,
        amount fee_rate, bool send_all)
    {
        GA_SDK_RUNTIME_ASSERT(!address_amount.empty() && !utxos.empty() && (!send_all || address_amount.size() == 1));

        amount total;
        std::vector<wally_tx_input_ptr> inputs;
        inputs.reserve(utxos.size());
        for (auto&& o : utxos) {
            if (!send_all && total >= address_amount[0].second) {
                break;
            }
            total += std::stoull(o.get<std::string>("value").c_str(), nullptr, 10);
            inputs.emplace_back(add_utxo(o));
        }

        std::vector<wally_tx_output_ptr> outputs;
        outputs.reserve(2);

        {
            const auto script = output_script_for_address(address_amount[0].first);
            outputs.emplace_back(create_tx_output(address_amount[0].second.value(), script.data(), script.size()));
        }

        const size_t block_height = m_block_height;

        wally_tx_ptr tx = make_tx(block_height, inputs, outputs);

        struct wally_tx_output* change_output{ nullptr };

        amount fee;

        for (;;) {
            fee = get_tx_fee(tx, fee_rate);
            const amount min_change = change_output ? amount() : get_dust_threshold();
            const amount am = address_amount[0].second + fee + min_change;
            if (total < am) {
                if (inputs.size() == utxos.size()) {
                    throw std::runtime_error("insufficient funds");
                }

                const utxo& u = *(utxos.begin() + inputs.size());
                total += std::stoull(u.get<std::string>("value").c_str(), nullptr, 10);
                inputs.emplace_back(add_utxo(u));
                continue;
            }

            if (total == am || change_output) {
                break;
            }

            {
                const auto change_address = get_receive_address(address_type::p2wsh, 0);
                const auto change_output_script = output_script_for_address(change_address.get<std::string>("p2wsh"));
                auto&& change_output_ptr
                    = create_tx_output(amount().value(), change_output_script.data(), change_output_script.size());
                change_output = change_output_ptr.get();
                outputs.emplace_back(std::move(change_output_ptr));
                tx = make_tx(block_height, inputs, outputs);
            }
        }

        if (change_output) {
            change_output->satoshi = (total - address_amount[0].second - fee).value();
            tx = make_tx(block_height, inputs, outputs);
        }

        std::vector<wally_tx_input_ptr> signed_inputs;
        signed_inputs.reserve(inputs.size());

        auto ub = utxos.begin();
        for (uint32_t i = 0; i < inputs.size(); ++i) {
            signed_inputs.emplace_back(sign_input(tx, i, *ub++));
        }

        tx = make_tx(block_height, signed_inputs, outputs);

        return hex_from_bytes(tx_to_bytes(tx));
    }

    void session::session_impl::send(const wally_string_ptr& raw_tx)
    {
        auto fn = m_session->call("com.greenaddress.vault.send_raw_tx", std::make_tuple(raw_tx.get()))
                      .then([](boost::future<autobahn::wamp_call_result> result) { result.get(); });

        fn.get();
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

    session::session() {}
    session::~session() {}

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

    void session::subscribe(const std::string& topic, std::function<void(const std::string& output)> handler)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->subscribe(topic, handler); });
    }

    receive_address session::get_receive_address(address_type addr_type, size_t subaccount)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_receive_address(addr_type, subaccount); });
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

    wally_string_ptr session::make_raw_tx(const std::vector<std::pair<std::string, amount>>& address_amount,
        const std::vector<utxo>& utxos, amount fee_rate, bool send_all)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->make_raw_tx(address_amount, utxos, fee_rate, send_all); });
    }

    void session::send(const wally_string_ptr& raw_tx)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->send(raw_tx); });
    }

    void session::send(const std::vector<std::pair<std::string, amount>>& address_amount,
        const std::vector<utxo>& utxos, amount fee_rate, bool send_all)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->send(address_amount, utxos, fee_rate, send_all); });
    }

    void session::send(
        const std::vector<std::pair<std::string, amount>>& address_amount, amount fee_rate, bool send_all)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->send(address_amount, fee_rate, send_all); });
    }
}
}
