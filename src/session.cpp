#include <algorithm>
#include <array>
#include <thread>
#include <type_traits>
#include <unordered_map>
#include <vector>

#include <boost/variant.hpp>

#include <autobahn/autobahn.hpp>
#include <autobahn/wamp_websocketpp_websocket_transport.hpp>

#include <websocketpp/client.hpp>
#include <websocketpp/config/asio_client.hpp>

extern "C" {
#include <wally_bip32.h>
#include <wally_bip39.h>
#include <wally_core.h>
#include <wally_crypto.h>
}

#include "assertion.hpp"
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

    struct event_loop_controller {
        explicit event_loop_controller(boost::asio::io_service& io)
            : _work_guard(std::make_unique<boost::asio::io_service::work>(io))
        {
            _run_thread = std::thread([&] { io.run(); });
        }

        ~event_loop_controller()
        {
            _work_guard.reset();
            _run_thread.join();
        }

        std::thread _run_thread;
        std::unique_ptr<boost::asio::io_service::work> _work_guard;
    };

    class session::session_impl {
    public:
        explicit session_impl(bool debug, bool tls)
            : _controller(_io)
            , _debug(debug)
            , _tls(tls)
        {
            _tls ? make_client<client_tls>() : (make_client<client>());
        }

        ~session_impl() { _io.stop(); }

        void connect(const std::string& endpoint);
        void register_user(const std::string& mnemonic, const std::string& salt);
        void login(const std::string& mnemonic);
        void subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler);

    private:
        static wally_string_ptr sign_challenge(wally_ext_key_ptr master_key, const std::string& challenge);

    private:
        template <typename T> std::enable_if_t<std::is_same<T, client>::value> set_tls_init_handler() {}
        template <typename T> std::enable_if_t<std::is_same<T, client_tls>::value> set_tls_init_handler()
        {
            // FIXME: these options need to be checked.
            boost::get<std::shared_ptr<T>>(_client)->set_tls_init_handler([](websocketpp::connection_hdl) {
                context_ptr ctx = std::make_shared<boost::asio::ssl::context>(boost::asio::ssl::context::tlsv1);
                ctx->set_options(boost::asio::ssl::context::default_workarounds | boost::asio::ssl::context::no_sslv2
                    | boost::asio::ssl::context::single_dh_use);
                return ctx;
            });
        }

        template <typename T> void make_client()
        {
            _client = std::make_shared<T>();
            boost::get<std::shared_ptr<T>>(_client)->init_asio(&_io);
            set_tls_init_handler<T>();
        }

        template <typename T> void make_transport(const std::string& endpoint)
        {
            using client_type
                = std::shared_ptr<std::conditional_t<std::is_same<T, transport_tls>::value, client_tls, client>>;

            _transport = std::make_shared<T>(*boost::get<client_type>(_client), endpoint, _debug),
            boost::get<std::shared_ptr<T>>(_transport)
                ->attach(std::static_pointer_cast<autobahn::wamp_transport_handler>(_session));
        }

        template <typename T> void connect_to_endpoint() const
        {
            std::array<boost::future<void>, 3> futures;

            futures[0] = boost::get<std::shared_ptr<T>>(_transport)->connect().then([&](boost::future<void> connected) {
                connected.get();
                futures[1] = _session->start().then([&](boost::future<void> started) {
                    started.get();
                    futures[2]
                        = _session->join(DEFAULT_REALM).then([&](boost::future<uint64_t> joined) { joined.get(); });
                });
            });

            for (auto&& f : futures) {
                f.get();
            }
        }

    private:
        boost::asio::io_service _io;
        boost::variant<std::shared_ptr<client>, std::shared_ptr<client_tls>> _client;
        boost::variant<std::shared_ptr<transport>, std::shared_ptr<transport_tls>> _transport;
        std::shared_ptr<autobahn::wamp_session> _session;

        event_loop_controller _controller;

        bool _debug;
        bool _tls;
    };

    void session::session_impl::connect(const std::string& endpoint)
    {
        _session = std::make_shared<autobahn::wamp_session>(_io, _debug);

        _tls ? make_transport<transport_tls>(endpoint) : make_transport<transport>(endpoint);
        _tls ? connect_to_endpoint<transport_tls>() : connect_to_endpoint<transport>();
    }

    wally_string_ptr session::session_impl::sign_challenge(wally_ext_key_ptr master_key, const std::string& challenge)
    {
        const uint32_t child_num = 0x4741b11e;
        const ext_key* r = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip32_key_from_parent_path_alloc(
                                  master_key.get(), &child_num, 1, BIP32_FLAG_KEY_PRIVATE | BIP32_FLAG_SKIP_HASH, &r)
            == WALLY_OK);
        wally_ext_key_ptr login_key(r, &bip32_key_free);

        const std::string challenge_ext = "greenaddress.it      login " + challenge;
        std::array<unsigned char, EC_MESSAGE_HASH_LEN> msg{ { 0 } };
        size_t written = 0;
        GA_SDK_RUNTIME_ASSERT(wally_format_bitcoin_message(reinterpret_cast<const unsigned char*>(challenge.data()),
                                  challenge.length(), BITCOIN_MESSAGE_FLAG_HASH, msg.data(), msg.size(), &written)
            == WALLY_OK);

        std::array<unsigned char, EC_SIGNATURE_LEN> sig{ { 0 } };
        GA_SDK_RUNTIME_ASSERT(wally_ec_sig_from_bytes(login_key->priv_key + 1, sizeof(login_key->priv_key) - 1,
                                  msg.data(), msg.size(), EC_FLAG_ECDSA, sig.data(), sig.size())
            == WALLY_OK);

        std::array<unsigned char, EC_SIGNATURE_DER_MAX_LEN> der{ { 0 } };
        GA_SDK_RUNTIME_ASSERT(
            wally_ec_sig_to_der(sig.data(), sig.size(), der.data(), der.size(), &written) == WALLY_OK);

        char* s = nullptr;
        GA_SDK_RUNTIME_ASSERT(wally_hex_from_bytes(der.data(), written, &s) == WALLY_OK);

        return wally_string_ptr(s, &wally_free_string);
    }

    void session::session_impl::register_user(const std::string& mnemonic, const std::string& salt)
    {
        std::array<unsigned char, PBKDF2_HMAC_SHA512_LEN> hash{ { 0 } };
        GA_SDK_RUNTIME_ASSERT(
            wally_pbkdf2_hmac_sha512(reinterpret_cast<const unsigned char*>(mnemonic.data()), mnemonic.length(),
                const_cast<unsigned char*>(reinterpret_cast<const unsigned char*>(salt.data())), salt.length(), 0, 2048,
                hash.data(), hash.size())
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

        char* q = nullptr;
        GA_SDK_RUNTIME_ASSERT(wally_hex_from_bytes(master_key->pub_key, sizeof(master_key->pub_key), &q) == WALLY_OK);
        wally_string_ptr pub_key(q, &wally_free_string);

        char* r = nullptr;
        GA_SDK_RUNTIME_ASSERT(
            wally_hex_from_bytes(master_key->chain_code, sizeof(master_key->chain_code), &r) == WALLY_OK);
        wally_string_ptr chain_code(r, &wally_free_string);

        char* s = nullptr;
        GA_SDK_RUNTIME_ASSERT(wally_hex_from_bytes(path.data(), path.size(), &s) == WALLY_OK);
        wally_string_ptr hex_path(s, &wally_free_string);

        std::tuple<std::string, std::string, std::string, std::string> register_arguments
            = std::make_tuple(pub_key.get(), chain_code.get(), "[sw]", hex_path.get());
        auto register_future = _session->call("com.greenaddress.login.register", register_arguments)
                                   .then([&](boost::future<autobahn::wamp_call_result> result) { result.get(); });

        register_future.get();
    }

    void session::session_impl::login(const std::string& mnemonic)
    {
        std::array<unsigned char, BIP39_SEED_LEN_512> seed{ { 0 } };
        size_t written = 0;
        GA_SDK_RUNTIME_ASSERT(
            bip39_mnemonic_to_seed(mnemonic.data(), NULL, seed.data(), seed.size(), &written) == WALLY_OK);

        const ext_key* p = nullptr;
        GA_SDK_RUNTIME_ASSERT(
            bip32_key_from_seed_alloc(seed.data(), seed.size(), BIP32_VER_TEST_PRIVATE, 0, &p) == WALLY_OK);
        wally_ext_key_ptr master_key(p, &bip32_key_free);

        std::array<unsigned char, sizeof(master_key->hash160) + 1> vpkh{ { 0 } };
        vpkh[0] = 111;
        std::copy(master_key->hash160, master_key->hash160 + sizeof(master_key->hash160), vpkh.begin() + 1);

        char* q = nullptr;
        GA_SDK_RUNTIME_ASSERT(wally_base58_from_bytes(vpkh.data(), vpkh.size(), BASE58_FLAG_CHECKSUM, &q) == WALLY_OK);
        wally_string_ptr base58_pkh(q, &wally_free_string);

        std::tuple<std::string> challenge_arguments{ std::string(q) };
        std::string challenge;
        auto get_challenge_future = _session->call("com.greenaddress.login.get_challenge", challenge_arguments)
                                        .then([&](boost::future<autobahn::wamp_call_result> result) {
                                            challenge = result.get().argument<std::string>(0);
                                            std::cerr << challenge << std::endl;
                                        });

        get_challenge_future.get();

        auto hexder = sign_challenge(std::move(master_key), challenge);

        std::tuple<std::string, bool, std::string, std::string, std::string> authenticate_arguments{
            std::string(hexder.get()), false, std::string("GA"), std::string("fake_dev_id"), std::string("[sw]")
        };

        bool succeeded = true;
        auto authenticate_future = _session->call("com.greenaddress.login.authenticate", authenticate_arguments)
                                       .then([&](boost::future<autobahn::wamp_call_result> result) {
                                           succeeded = result.get().argument<bool>(0);
                                       });

        authenticate_future.get();
    }

    void session::session_impl::subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler)
    {
        auto subscribe_future = _session->subscribe(topic, handler, autobahn::wamp_subscribe_options("exact"))
                                    .then([&](boost::future<autobahn::wamp_subscription> subscription) {
                                        std::cerr << "subscribed to topic:" << subscription.get().id() << std::endl;
                                    });

        subscribe_future.get();
    }

    void session::connect(const std::string& endpoint, bool debug)
    {
        _impl = std::make_shared<session::session_impl>(debug, false);

        try {
            _impl->connect(endpoint);
        } catch (const std::exception& ex) {
            std::cerr << ex.what() << std::endl;
        }
    }

    void session::disconnect() { _impl.reset(); }

    void session::register_user(const std::string& mnemonic, const std::string& salt)
    {
        try {
            _impl->register_user(mnemonic, salt);
        } catch (const std::exception& ex) {
            std::cerr << ex.what() << std::endl;
        }
    }

    void session::login(const std::string& mnemonic)
    {
        try {
            _impl->login(mnemonic);
        } catch (const std::exception& ex) {
            std::cerr << ex.what() << std::endl;
        }
    }

    void session::subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler)
    {
        try {
            _impl->subscribe(topic, handler);
        } catch (const std::exception& ex) {
            std::cerr << ex.what() << std::endl;
        }
    }
}
}
