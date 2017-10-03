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

#include <wally_bip32.h>
#include <wally_bip39.h>
#include <wally_core.h>
#include <wally_crypto.h>

#include "assertion.hpp"
#include "exception.hpp"
#include "session.hpp"
#include "transaction_utils.hpp"

namespace ga {
namespace sdk {
    using client = websocketpp::client<websocketpp::config::asio_client>;
    using client_tls = websocketpp::client<websocketpp::config::asio_tls_client>;
    using transport = autobahn::wamp_websocketpp_websocket_transport<websocketpp::config::asio_client>;
    using transport_tls = autobahn::wamp_websocketpp_websocket_transport<websocketpp::config::asio_tls_client>;
    using context_ptr = websocketpp::lib::shared_ptr<boost::asio::ssl::context>;

    using wally_ext_key_ptr = std::unique_ptr<const ext_key, decltype(&bip32_key_free)>;

    const std::string DEFAULT_REALM("realm1");
    const std::string DEFAULT_USER_AGENT("[v2,sw]");

    namespace {
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
            , m_master_key(nullptr, &bip32_key_free)
            , m_debug(debug)
        {
            connect_with_tls() ? make_client<client_tls>() : make_client<client>();
        }

        ~session_impl() { m_io.stop(); }

        void connect();
        void register_user(const std::string& mnemonic, const std::string& user_agent);
        login_data login(const std::string& mnemonic, const std::string& user_agent);
        bool remove_account();

        login_data login(const std::string& pin, const std::pair<std::string, std::string>& pin_identifier_and_secret,
            const std::string& user_agent = std::string());
        void change_settings_helper(settings key, const std::map<int, int>& args);

        tx_list get_tx_list(const std::pair<std::time_t, std::time_t>& date_range, size_t subaccount,
            tx_list_sort_by sort_by, size_t page_id, const std::string& query);
        void subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler);
        receive_address get_receive_address(address_type addr_type, size_t subaccount) const;
        template <typename T> balance get_balance(T subaccount, size_t num_confs) const;
        two_factor get_twofactor_config();
        bool set_twofactor(two_factor_type type, const std::string& code, const std::string& proxy_code);
        pin_info set_pin(const std::string& mnemonic, const std::string& pin, const std::string& device);

    private:
        static std::pair<wally_string_ptr, wally_string_ptr> sign_challenge(
            wally_ext_key_ptr master_key, const std::string& challenge);

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

        std::string get_pin_password(const std::string& pin, const std::string& pin_identifier);

        std::string get_raw_output(const std::string& txhash) const;
        std::vector<unsigned char> output_script(int32_t subaccount, uint32_t pointer) const;
        utxo get_utxos(size_t num_confs, size_t subaccount) const;

    private:
        boost::asio::io_service m_io;
        boost::variant<std::shared_ptr<client>, std::shared_ptr<client_tls>> m_client;
        boost::variant<std::shared_ptr<transport>, std::shared_ptr<transport_tls>> m_transport;
        std::shared_ptr<autobahn::wamp_session> m_session;

        event_loop_controller m_controller;

        network_parameters m_params;

        login_data m_login_data;
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
        std::array<unsigned char, BIP39_SEED_LEN_512> seed{ { 0 } };
        size_t written = 0;
        GA_SDK_RUNTIME_ASSERT(
            bip39_mnemonic_to_seed(mnemonic.data(), NULL, seed.data(), seed.size(), &written) == WALLY_OK);

        const ext_key* p = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip32_key_from_seed_alloc(seed.data(), seed.size(),
                                  m_params.main_net() ? BIP32_VER_MAIN_PRIVATE : BIP32_VER_TEST_PRIVATE, 0, &p)
            == WALLY_OK);
        wally_ext_key_ptr master_key(p, &bip32_key_free);

        std::array<unsigned char, sizeof(master_key->chain_code) + sizeof(master_key->pub_key)> path_data;
        std::copy(master_key->chain_code, master_key->chain_code + sizeof(master_key->chain_code), path_data.data());
        std::copy(master_key->pub_key, master_key->pub_key + sizeof(master_key->pub_key),
            path_data.data() + sizeof(master_key->chain_code));

        const std::string key = "GreenAddress.it HD wallet path";
        std::array<unsigned char, HMAC_SHA512_LEN> path{ { 0 } };
        GA_SDK_RUNTIME_ASSERT(wally_hmac_sha512(reinterpret_cast<const unsigned char*>(key.data()), key.length(),
                                  path_data.data(), path_data.size(), path.data(), path.size())
            == WALLY_OK);

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

    login_data session::session_impl::login(const std::string& mnemonic, const std::string& user_agent)
    {
        std::array<unsigned char, BIP39_SEED_LEN_512> seed{ { 0 } };
        size_t written = 0;
        GA_SDK_RUNTIME_ASSERT(
            bip39_mnemonic_to_seed(mnemonic.data(), NULL, seed.data(), seed.size(), &written) == WALLY_OK);

        const ext_key* p = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip32_key_from_seed_alloc(seed.data(), seed.size(),
                                  m_params.main_net() ? BIP32_VER_MAIN_PRIVATE : BIP32_VER_TEST_PRIVATE, 0, &p)
            == WALLY_OK);
        m_master_key = wally_ext_key_ptr(p, &bip32_key_free);

        std::array<unsigned char, sizeof(m_master_key->hash160) + 1> vpkh{ { 0 } };
        vpkh[0] = m_params.btc_version();
        std::copy(m_master_key->hash160, m_master_key->hash160 + sizeof(m_master_key->hash160), vpkh.begin() + 1);

        char* q = nullptr;
        GA_SDK_RUNTIME_ASSERT(wally_base58_from_bytes(vpkh.data(), vpkh.size(), BASE58_FLAG_CHECKSUM, &q) == WALLY_OK);
        wally_string_ptr base58_pkh(q, &wally_free_string);

        auto challenge_arguments = std::make_tuple(base58_pkh.get());
        std::string challenge;
        auto get_challenge_future = m_session->call("com.greenaddress.login.get_challenge", challenge_arguments)
                                        .then([&challenge](boost::future<autobahn::wamp_call_result> result) {
                                            challenge = result.get().argument<std::string>(0);
                                        });

        get_challenge_future.get();

        struct ext_key master_key = *m_master_key;
        auto hexder_path
            = sign_challenge(wally_ext_key_ptr(&master_key, [](const struct ext_key*) { return WALLY_OK; }), challenge);

        auto authenticate_arguments = std::make_tuple(hexder_path.first.get(), false, hexder_path.second.get(),
            std::string("fake_dev_id"), DEFAULT_USER_AGENT + user_agent + "_ga_sdk");
        auto authenticate_future = m_session->call("com.greenaddress.login.authenticate", authenticate_arguments)
                                       .then([this](boost::future<autobahn::wamp_call_result> result) {
                                           m_login_data = result.get().argument<msgpack::object>(0);
                                       });

        authenticate_future.get();

        return m_login_data;
    }

    bool session::session_impl::remove_account()
    {
        bool r;
        auto remove_account_future
            = m_session
                  ->call("com.greenaddress.login.remove_account", std::make_tuple(std::map<std::string, std::string>()))
                  .then([&r](boost::future<autobahn::wamp_call_result> result) { r = result.get().argument<bool>(0); });

        remove_account_future.get();

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
        auto get_tx_list_future = m_session->call("com.greenaddress.txs.get_list_v2", get_tx_list_arguments)
                                      .then([&txs](boost::future<autobahn::wamp_call_result> result) {
                                          txs.associate(result.get().argument<msgpack::object>(0));
                                      });

        get_tx_list_future.get();

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

    std::string session::session_impl::get_raw_output(const std::string& txhash) const
    {
        std::string raw_output;
        auto raw_output_future = m_session->call("com.greenaddress.txs.get_raw_output", std::make_tuple(txhash))
                                     .then([&raw_output](boost::future<autobahn::wamp_call_result> result) {
                                         raw_output = result.get().argument<std::string>(0);
                                     });

        raw_output_future.get();

        return raw_output;
    }

    std::vector<unsigned char> session::session_impl::output_script(int32_t subaccount, uint32_t pointer) const
    {
        return ga::sdk::output_script(m_master_key, m_params.deposit_chain_code(), m_params.deposit_pub_key(),
            m_login_data.get<std::string>("gait_path"), subaccount, pointer, m_params.main_net());
    }

    utxo session::session_impl::get_utxos(size_t num_confs, size_t subaccount) const
    {
        utxo unspent;
        auto unspent_outputs_future
            = m_session
                  ->call("com.greenaddress.txs.get_all_unspent_outputs", std::make_tuple(num_confs, subaccount, "any"))
                  .then([&unspent](boost::future<autobahn::wamp_call_result> result) {
                      const auto r = result.get();
                      if (r.number_of_arguments()) {
                          unspent = r.argument<msgpack::object>(0);
                      }
                  });

        return unspent;
    }

    receive_address session::session_impl::get_receive_address(address_type addr_type, size_t subaccount) const
    {
        const std::string addr_type_str = addr_type == address_type::p2sh ? "p2sh" : "p2wsh";

        receive_address address;
        auto receive_address_future
            = m_session->call("com.greenaddress.vault.fund", std::make_tuple(subaccount, true, addr_type_str))
                  .then([&address](boost::future<autobahn::wamp_call_result> result) {
                      address = result.get().argument<msgpack::object>(0);
                  });

        receive_address_future.get();

        const auto script = address.get<std::string>("script");
        const auto pointer = address.get<int>("pointer");
        const auto script_bytes = bytes_from_hex(script.data(), script.length());
        const auto hash160
            = addr_type == address_type::p2sh ? create_p2sh_script(script_bytes) : create_p2wsh_script(script_bytes);

        const auto multisig = output_script(subaccount, pointer);
        const auto hash160_multisig
            = addr_type == address_type::p2sh ? create_p2sh_script(multisig) : create_p2wsh_script(multisig);

        GA_SDK_RUNTIME_ASSERT(hash160 == hash160_multisig);

        char* q = nullptr;
        GA_SDK_RUNTIME_ASSERT(
            wally_base58_from_bytes(hash160.data(), hash160.size(), BASE58_FLAG_CHECKSUM, &q) == WALLY_OK);
        wally_string_ptr base58_pkh(q, &wally_free_string);

        address.set(addr_type_str, std::string(q));

        return address;
    }

    template <typename T> balance session::session_impl::get_balance(T subaccount, size_t num_confs) const
    {
        balance b;

        auto balance_future
            = m_session->call("com.greenaddress.txs.get_balance", std::make_tuple(subaccount, num_confs))
                  .then([&b](boost::future<autobahn::wamp_call_result> result) {
                      b = result.get().argument<msgpack::object>(0);
                  });

        balance_future.get();

        return b;
    }

    two_factor session::session_impl::get_twofactor_config()
    {
        two_factor f;

        auto two_factor_future = m_session->call("com.greenaddress.twofactor.get_config", std::make_tuple())
                                     .then([&f](boost::future<autobahn::wamp_call_result> result) {
                                         f = result.get().argument<msgpack::object>(0);
                                     });

        two_factor_future.get();

        return f;
    }

    bool session::session_impl::set_twofactor(__attribute__((unused)) two_factor_type type, const std::string& code,
        __attribute__((unused)) const std::string& proxy_code)
    {
        auto two_factor_future
            = m_session
                  ->call("com.greenaddress.twofactor.enable_gauth",
                      // std::make_tuple(code, std::map<std::string, std::string>{ { "proxy", proxy_code } }))
                      std::make_tuple(code, std::map<std::string, std::string>()))
                  .then([](boost::future<autobahn::wamp_call_result> result) { result.get(); });

        two_factor_future.get();

        return false;
    }

    pin_info session::session_impl::set_pin(
        const std::string& mnemonic, const std::string& pin, const std::string& device)
    {
        GA_SDK_RUNTIME_ASSERT(pin.length() >= 4);

        std::string pin_identifier;

        auto set_pin_future = m_session->call("com.greenaddress.pin.set_pin_login", std::make_tuple(pin, device))
                                  .then([&pin_identifier](boost::future<autobahn::wamp_call_result> result) {
                                      pin_identifier = result.get().argument<std::string>(0);
                                  });

        set_pin_future.get();

        const auto password = get_pin_password(pin, pin_identifier);

        auto salt = get_random_bytes<16>();
        const auto salt_hex = hex_from_bytes(salt.data(), salt.size());

        std::array<unsigned char, BIP39_SEED_LEN_512> seed{ { 0 } };
        size_t written = 0;
        GA_SDK_RUNTIME_ASSERT(
            bip39_mnemonic_to_seed(mnemonic.data(), NULL, seed.data(), seed.size(), &written) == WALLY_OK);
        const auto seed_hex = hex_from_bytes(seed.data(), written);
        const auto mnemonic_bytes = mnemonic_to_bytes(mnemonic, "en");
        const auto mnemonic_hex = hex_from_bytes(mnemonic_bytes.data(), mnemonic_bytes.size());

        std::array<unsigned char, PBKDF2_HMAC_SHA512_LEN> key;
        GA_SDK_RUNTIME_ASSERT(wally_pbkdf2_hmac_sha512(reinterpret_cast<const unsigned char*>(password.data()),
                                  password.size(), salt.data(), salt.size(), 0, 2048, key.data(), key.size())
            == WALLY_OK);

        std::array<unsigned char, BIP39_SEED_LEN_512 + BIP39_ENTROPY_LEN_256> data{ { 0 } };
        std::copy(seed.begin(), seed.end(), data.begin());
        std::copy(mnemonic_bytes.begin(), mnemonic_bytes.end(), data.begin() + BIP39_SEED_LEN_512);

        const auto iv = get_random_bytes<AES_BLOCK_LEN>();

        std::vector<unsigned char> encrypted(iv.size() + ((data.size() / AES_BLOCK_LEN) + 1) * AES_BLOCK_LEN);
        std::copy(iv.begin(), iv.end(), encrypted.begin());
        GA_SDK_RUNTIME_ASSERT(
            wally_aes_cbc(key.data(), AES_KEY_LEN_256, iv.data(), iv.size(), data.data(), data.size(), AES_FLAG_ENCRYPT,
                encrypted.data() + iv.size(), encrypted.size() - iv.size(), &written)
            == WALLY_OK);
        GA_SDK_RUNTIME_ASSERT(written == encrypted.size() - iv.size());

        const auto encrypted_hex = hex_from_bytes(encrypted.data(), iv.size() + written);

        pin_info p;
        p.emplace("secret", std::string(salt_hex.get()) + std::string(encrypted_hex.get()));
        p.emplace("pin_identifier", pin_identifier);

        return p;
    }

    std::string session::session_impl::get_pin_password(const std::string& pin, const std::string& pin_identifier)
    {
        std::string password;

        auto get_pin_password_future
            = m_session->call("com.greenaddress.pin.get_password", std::make_tuple(pin, pin_identifier))
                  .then([&password](boost::future<autobahn::wamp_call_result> result) {
                      password = result.get().argument<std::string>(0);
                  });

        get_pin_password_future.get();

        return password;
    }

    login_data session::session_impl::login(const std::string& pin,
        const std::pair<std::string, std::string>& pin_identifier_and_secret, const std::string& user_agent)
    {
        const auto password = get_pin_password(pin, pin_identifier_and_secret.first);

        auto secret_bytes
            = bytes_from_hex(pin_identifier_and_secret.second.data(), pin_identifier_and_secret.second.size());

        std::array<unsigned char, PBKDF2_HMAC_SHA512_LEN> key;
        GA_SDK_RUNTIME_ASSERT(wally_pbkdf2_hmac_sha512(reinterpret_cast<const unsigned char*>(password.data()),
                                  password.size(), secret_bytes.data(), 16, 0, 2048, key.data(), key.size())
            == WALLY_OK);

        std::vector<unsigned char> plaintext(secret_bytes.size() - AES_BLOCK_LEN - 16);
        size_t written = 0;
        GA_SDK_RUNTIME_ASSERT(wally_aes_cbc(key.data(), AES_KEY_LEN_256, secret_bytes.data(), 16,
                                  secret_bytes.data() + 16 + AES_BLOCK_LEN, secret_bytes.size() - AES_BLOCK_LEN - 16,
                                  AES_FLAG_DECRYPT, plaintext.data(), plaintext.size(), &written)
            == WALLY_OK);
        GA_SDK_RUNTIME_ASSERT(written <= plaintext.size() && (plaintext.size() - written <= AES_BLOCK_LEN));

        const auto mnemonic = mnemonic_from_bytes(plaintext.data() + BIP39_SEED_LEN_512, BIP39_ENTROPY_LEN_256, "en");

        return login(std::string(mnemonic.get()), user_agent);
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
            m_impl = std::make_shared<session::session_impl>(std::move(params), debug);
            m_impl->connect();
        });
    }

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

    void session::subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler)
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
}
}
