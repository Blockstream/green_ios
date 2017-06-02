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

#include <autobahn/autobahn.hpp>
#include <autobahn/wamp_websocketpp_websocket_transport.hpp>

#include <websocketpp/client.hpp>
#include <websocketpp/config/asio_client.hpp>

#include <wally_bip32.h>
#include <wally_bip39.h>
#include <wally_core.h>
#include <wally_crypto.h>

#include "assertion.hpp"
#include "session.h"
#include "session.hpp"

namespace ga {
namespace sdk {
    using client = websocketpp::client<websocketpp::config::asio_client>;
    using client_tls = websocketpp::client<websocketpp::config::asio_tls_client>;
    using transport = autobahn::wamp_websocketpp_websocket_transport<websocketpp::config::asio_client>;
    using transport_tls = autobahn::wamp_websocketpp_websocket_transport<websocketpp::config::asio_tls_client>;
    using context_ptr = websocketpp::lib::shared_ptr<boost::asio::ssl::context>;

    using wally_ext_key_ptr = std::unique_ptr<const ext_key, decltype(&bip32_key_free)>;
    using wally_string_ptr = std::unique_ptr<char, decltype(&wally_free_string)>;

    const std::string DEFAULT_REALM("realm1");
    const std::string DEFAULT_USER_AGENT("[v2,sw]");

    namespace {
        wally_string_ptr hex_from_bytes(const unsigned char* bytes, size_t siz)
        {
            char* s = nullptr;
            GA_SDK_RUNTIME_ASSERT(wally_hex_from_bytes(bytes, siz, &s) == WALLY_OK);
            return wally_string_ptr(s, &wally_free_string);
        }

        // FIXME: too slow. lacks validation.
        std::array<unsigned char, 32> uint256_to_base256(const std::string& bytes)
        {
            constexpr size_t base = 256;

            std::array<unsigned char, 32> repr = { { 0 } };
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
        explicit session_impl(network_parameters params, bool debug)
            : m_controller(m_io)
            , m_params(std::move(params))
            , m_debug(debug)
        {
            connect_with_tls() ? make_client<client_tls>() : make_client<client>();
        }

        ~session_impl() { m_io.stop(); }

        void connect();
        void register_user(const std::string& mnemonic, const std::string& user_agent);
        void login(const std::string& mnemonic, const std::string& user_agent);
        void change_settings_helper(settings key, const std::map<int, int>& args);
        void get_tx_list(size_t page_id, const std::string& query, tx_list_sort_by sort_by,
            const std::pair<std::time_t, std::time_t>& date_range, size_t subaccount);
        void subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler);

    private:
        static std::pair<wally_string_ptr, wally_string_ptr> sign_challenge(
            wally_ext_key_ptr master_key, const std::string& challenge);

    private:
        bool connect_with_tls() const { return boost::algorithm::starts_with(m_params.gait_wamp_url(), "wss://"); }

        template <typename T> std::enable_if_t<std::is_same<T, client>::value> set_tls_init_handler() {}
        template <typename T> std::enable_if_t<std::is_same<T, client_tls>::value> set_tls_init_handler()
        {
            // FIXME: these options need to be checked.
            boost::get<std::shared_ptr<T>>(m_client)->set_tls_init_handler([](websocketpp::connection_hdl) {
                context_ptr ctx = std::make_shared<boost::asio::ssl::context>(boost::asio::ssl::context::tlsv1);
                ctx->set_options(boost::asio::ssl::context::default_workarounds | boost::asio::ssl::context::no_sslv2
                    | boost::asio::ssl::context::single_dh_use);
                return ctx;
            });
        }

        template <typename T> void make_client()
        {
            m_client = std::make_shared<T>();
            boost::get<std::shared_ptr<T>>(m_client)->init_asio(&m_io);
            set_tls_init_handler<T>();
        }

        template <typename T> void make_transport()
        {
            using client_type
                = std::shared_ptr<std::conditional_t<std::is_same<T, transport_tls>::value, client_tls, client>>;

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

    private:
        boost::asio::io_service m_io;
        boost::variant<std::shared_ptr<client>, std::shared_ptr<client_tls>> m_client;
        boost::variant<std::shared_ptr<transport>, std::shared_ptr<transport_tls>> m_transport;
        std::shared_ptr<autobahn::wamp_session> m_session;

        event_loop_controller m_controller;

        std::unordered_map<std::string, msgpack::object> m_login_data;

        network_parameters m_params;

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
        wally_ext_key_ptr master_key, const std::string& challenge)
    {
        auto random_path = get_random_bytes<8>();

        std::array<uint32_t, 4> child_num;
        adjacent_transform(std::begin(random_path), std::end(random_path), std::begin(child_num),
            [](auto first, auto second) { return uint32_t((first << 8) + second); });

        wally_ext_key_ptr login_key = std::move(master_key);
        const ext_key* r = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip32_key_from_parent_path_alloc(login_key.get(), child_num.data(), child_num.size(),
                                  BIP32_FLAG_KEY_PRIVATE | BIP32_FLAG_SKIP_HASH, &r)
            == WALLY_OK);

        login_key = wally_ext_key_ptr(r, &bip32_key_free);

        const auto challenge_hash = uint256_to_base256(challenge);
        std::array<unsigned char, EC_SIGNATURE_LEN> sig{ { 0 } };
        GA_SDK_RUNTIME_ASSERT(wally_ec_sig_from_bytes(login_key->priv_key + 1, sizeof(login_key->priv_key) - 1,
                                  challenge_hash.data(), challenge_hash.size(), EC_FLAG_ECDSA, sig.data(), sig.size())
            == WALLY_OK);

        std::array<unsigned char, EC_SIGNATURE_DER_MAX_LEN> der{ { 0 } };
        size_t written = 0;
        GA_SDK_RUNTIME_ASSERT(
            wally_ec_sig_to_der(sig.data(), sig.size(), der.data(), der.size(), &written) == WALLY_OK);

        return { hex_from_bytes(der.data(), written), hex_from_bytes(random_path.data(), random_path.size()) };
    }

    void session::session_impl::register_user(const std::string& mnemonic, const std::string& user_agent)
    {
        unsigned char salt[] = "greenaddress_path";
        std::array<unsigned char, PBKDF2_HMAC_SHA512_LEN> hash{ { 0 } };
        GA_SDK_RUNTIME_ASSERT(wally_pbkdf2_hmac_sha512(reinterpret_cast<const unsigned char*>(mnemonic.data()),
                                  mnemonic.length(), salt, sizeof(salt), 0, 2048, hash.data(), hash.size())
            == WALLY_OK);

        const std::string key = "GreenAddress.it HD wallet path";
        std::array<unsigned char, HMAC_SHA512_LEN> path{ { 0 } };
        GA_SDK_RUNTIME_ASSERT(wally_hmac_sha512(reinterpret_cast<const unsigned char*>(key.data()), key.length(),
                                  hash.data(), hash.size(), path.data(), path.size())
            == WALLY_OK);

        std::array<unsigned char, BIP39_SEED_LEN_512> seed{ { 0 } };
        size_t written = 0;
        GA_SDK_RUNTIME_ASSERT(
            bip39_mnemonic_to_seed(mnemonic.data(), NULL, seed.data(), seed.size(), &written) == WALLY_OK);

        const ext_key* p = nullptr;
        GA_SDK_RUNTIME_ASSERT(
            bip32_key_from_seed_alloc(seed.data(), seed.size(), BIP32_VER_TEST_PRIVATE, 0, &p) == WALLY_OK);
        wally_ext_key_ptr master_key(p, &bip32_key_free);

        auto pub_key = hex_from_bytes(master_key->pub_key, sizeof(master_key->pub_key));
        auto chain_code = hex_from_bytes(master_key->chain_code, sizeof(master_key->chain_code));
        auto hex_path = hex_from_bytes(path.data(), path.size());

        auto register_arguments = std::make_tuple(
            pub_key.get(), chain_code.get(), DEFAULT_USER_AGENT + user_agent + "_ga_sdk", hex_path.get());
        auto register_future = m_session->call("com.greenaddress.login.register", register_arguments)
                                   .then([](boost::future<autobahn::wamp_call_result> result) {
                                       GA_SDK_RUNTIME_ASSERT(result.get().argument<bool>(0));
                                   });

        register_future.get();
    }

    void session::session_impl::login(const std::string& mnemonic, const std::string& user_agent)
    {
        std::array<unsigned char, BIP39_SEED_LEN_512> seed{ { 0 } };
        size_t written = 0;
        GA_SDK_RUNTIME_ASSERT(
            bip39_mnemonic_to_seed(mnemonic.data(), NULL, seed.data(), seed.size(), &written) == WALLY_OK);

        const ext_key* p = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip32_key_from_seed_alloc(seed.data(), seed.size(),
                                  m_params.main_net() ? BIP32_VER_MAIN_PRIVATE : BIP32_VER_TEST_PRIVATE, 0, &p)
            == WALLY_OK);
        wally_ext_key_ptr master_key(p, &bip32_key_free);

        std::array<unsigned char, sizeof(master_key->hash160) + 1> vpkh{ { 0 } };
        vpkh[0] = m_params.btc_version();
        std::copy(master_key->hash160, master_key->hash160 + sizeof(master_key->hash160), vpkh.begin() + 1);

        char* q = nullptr;
        GA_SDK_RUNTIME_ASSERT(wally_base58_from_bytes(vpkh.data(), vpkh.size(), BASE58_FLAG_CHECKSUM, &q) == WALLY_OK);
        wally_string_ptr base58_pkh(q, &wally_free_string);

        auto challenge_arguments = std::make_tuple(base58_pkh.get());
        std::string challenge;
        auto get_challenge_future = m_session->call("com.greenaddress.login.get_challenge", challenge_arguments)
                                        .then([&challenge](boost::future<autobahn::wamp_call_result> result) {
                                            challenge = result.get().argument<std::string>(0);
                                            std::cerr << challenge << std::endl;
                                        });

        get_challenge_future.get();

        auto hexder_path = sign_challenge(std::move(master_key), challenge);

        auto authenticate_arguments = std::make_tuple(hexder_path.first.get(), false, hexder_path.second.get(),
            std::string("fake_dev_id"), DEFAULT_USER_AGENT + user_agent + "_ga_sdk");
        auto authenticate_future = m_session->call("com.greenaddress.login.authenticate", authenticate_arguments)
                                       .then([this](boost::future<autobahn::wamp_call_result> result) {
                                           m_login_data = result.get().argument<decltype(m_login_data)>(0);
                                       });

        authenticate_future.get();
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
            auto change_settings_future
                = m_session->call("com.greenaddress.login.change_settings", change_settings_arguments)
                      .then([](boost::future<autobahn::wamp_call_result> result) {
                          GA_SDK_RUNTIME_ASSERT(result.get().argument<bool>(0));
                      });

            change_settings_future.get();
        };

        if (key == settings::tx_limits) {
            change_settings(to_args({ "is_fiat", "per_tx", "total" }));
        } else {
            GA_SDK_RUNTIME_ASSERT(args.size());
            change_settings((*args.begin()).first);
        }
    }

    void session::session_impl::get_tx_list(size_t page_id, const std::string& query, tx_list_sort_by sort_by,
        const std::pair<std::time_t, std::time_t>& date_range, size_t subaccount)
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
            constexpr auto iso_str_siz = sizeof("0000-00-00T00:00:00Z");

            std::array<char, iso_str_siz> begin_date_str = { { 0 } };
            std::array<char, iso_str_siz> end_date_str = { { 0 } };

            struct tm tm_;
            std::strftime(begin_date_str.data(), begin_date_str.size(), "%FT%TZ", gmtime_r(&date_range.first, &tm_));
            std::strftime(end_date_str.data(), end_date_str.size(), "%FT%TZ", gmtime_r(&date_range.second, &tm_));

            return std::make_pair(std::string(begin_date_str.data()), std::string(end_date_str.data()));
        };

        auto get_tx_list_arguments = std::make_tuple(page_id, query, sort_by_str(), date_range_str(), subaccount);
        auto get_tx_list_future = m_session->call("com.greenaddress.txs.get_list_v2", get_tx_list_arguments)
                                      .then([](boost::future<autobahn::wamp_call_result> result) { result.get(); });

        get_tx_list_future.get();
    }

    void session::session_impl::subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler)
    {
        auto subscribe_future = m_session->subscribe(topic, handler, autobahn::wamp_subscribe_options("exact"))
                                    .then([](boost::future<autobahn::wamp_subscription> subscription) {
                                        std::cerr << "subscribed to topic:" << subscription.get().id() << std::endl;
                                    });

        subscribe_future.get();
    }

    void session::connect(network_parameters params, bool debug)
    {
        m_impl = std::make_shared<session::session_impl>(std::move(params), debug);

        m_impl->connect();
    }

    void session::disconnect() { m_impl.reset(); }

    void session::register_user(const std::string& mnemonic, const std::string& user_agent)
    {
        m_impl->register_user(mnemonic, user_agent);
    }

    void session::login(const std::string& mnemonic, const std::string& user_agent)
    {
        m_impl->login(mnemonic, user_agent);
    }

    void session::change_settings_helper(settings key, const std::map<int, int>& args)
    {
        m_impl->change_settings_helper(key, args);
    }

    void session::get_tx_list(size_t page_id, const std::string& query, tx_list_sort_by sort_by,
        const std::pair<std::time_t, std::time_t>& date_range, size_t subaccount)
    {
        m_impl->get_tx_list(page_id, query, sort_by, date_range, subaccount);
    }

    void session::subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler)
    {
        m_impl->subscribe(topic, handler);
    }
}
}

namespace {
template <typename F, typename... Args> auto c_invoke(F&& f, struct GA_session* session, Args&&... args)
{
    try {
        GA_SDK_RUNTIME_ASSERT(session);
        f(session, std::forward<Args>(args)...);
        return GA_OK;
    } catch (const std::exception& ex) {
        std::cerr << ex.what() << std::endl;
        return GA_ERROR;
    }
    __builtin_unreachable();
}
}

struct GA_session final : public ga::sdk::session {
};

#define GA_SDK_DEFINE_C_FUNCTION_0(c_function_name, c_function_body)                                                   \
    int c_function_name(struct GA_session* session) { return c_invoke(c_function_body, session); }

#define GA_SDK_DEFINE_C_FUNCTION_1(c_function_name, c_function_body, T1, ARG1)                                         \
    int c_function_name(struct GA_session* session, T1 ARG1) { return c_invoke(c_function_body, session, ARG1); }

#define GA_SDK_DEFINE_C_FUNCTION_2(c_function_name, c_function_body, T1, ARG1, T2, ARG2)                               \
    int c_function_name(struct GA_session* session, T1 ARG1, T2 ARG2)                                                  \
    {                                                                                                                  \
        return c_invoke(c_function_body, session, ARG1, ARG2);                                                         \
    }

#define GA_SDK_DEFINE_C_FUNCTION_3(c_function_name, c_function_body, T1, ARG1, T2, ARG2, T3, ARG3)                     \
    int c_function_name(struct GA_session* session, T1 ARG1, T2 ARG2, T3 ARG3)                                         \
    {                                                                                                                  \
        return c_invoke(c_function_body, session, ARG1, ARG2, ARG3);                                                   \
    }

int GA_create_session(struct GA_session** session)
{
    try {
        GA_SDK_RUNTIME_ASSERT(session);
        *session = new GA_session();
        return GA_OK;
    } catch (const std::exception& ex) {
        return GA_ERROR;
    }
    __builtin_unreachable();
}

void GA_destroy_session(struct GA_session* session)
{
    delete session;
    session = nullptr;
}

GA_SDK_DEFINE_C_FUNCTION_2(GA_connect,
    [](struct GA_session* session, int network, int debug) {
        auto&& params = network == GA_NETWORK_REGTEST ? ga::sdk::make_regtest_network()
                                                      : network == GA_NETWORK_LOCALTEST
                ? ga::sdk::make_localtest_network()
                : network == GA_NETWORK_TESTNET ? ga::sdk::make_testnet_network() : ga::sdk::make_localtest_network();
        session->connect(std::move(params), debug != 0);
    },
    int, network, int, debug)

GA_SDK_DEFINE_C_FUNCTION_0(GA_disconnect, [](struct GA_session* session) { session->disconnect(); })

GA_SDK_DEFINE_C_FUNCTION_1(GA_register_user,
    [](struct GA_session* session, const char* mnemonic) { session->register_user(mnemonic); }, const char*, mnemonic)

GA_SDK_DEFINE_C_FUNCTION_1(GA_login, [](struct GA_session* session, const char* mnemonic) { session->login(mnemonic); },
    const char*, mnemonic);

GA_SDK_DEFINE_C_FUNCTION_1(GA_change_settings_privacy_send_me,
    [](struct GA_session* session, int param) {
        namespace sdk = ga::sdk;
        session->change_settings(sdk::settings::privacy_send_me, sdk::privacy_send_me(param));
    },
    int, param);

GA_SDK_DEFINE_C_FUNCTION_1(GA_change_settings_privacy_show_as_sender,
    [](struct GA_session* session, int param) {
        namespace sdk = ga::sdk;
        session->change_settings(sdk::settings::privacy_show_as_sender, sdk::privacy_show_as_sender(param));
    },
    int, param);

GA_SDK_DEFINE_C_FUNCTION_3(GA_change_settings_tx_limits,
    [](struct GA_session* session, int is_fiat, int per_tx, int total) {
        namespace sdk = ga::sdk;
        session->change_settings(sdk::settings::tx_limits, sdk::tx_limits::is_fiat, is_fiat, sdk::tx_limits::per_tx,
            per_tx, sdk::tx_limits::total, total);
    },
    int, is_fiat, int, per_tx, int, total);
