#ifndef GA_SDK_GA_SESSION_HPP
#define GA_SDK_GA_SESSION_HPP
#pragma once

#include <array>
#include <map>
#include <string>
#include <thread>
#include <type_traits>
#include <vector>

#include "autobahn_wrapper.hpp"
#include "boost_wrapper.hpp"
#include "logging.hpp"
#include "signer.hpp"
#include "xpub_hdkey.hpp"

namespace ga {
namespace sdk {
    struct websocketpp_gdk_config;
    struct websocketpp_gdk_tls_config;

    using client = websocketpp::client<websocketpp_gdk_config>;
    using client_tls = websocketpp::client<websocketpp_gdk_tls_config>;
    using transport = autobahn::wamp_websocketpp_websocket_transport<websocketpp_gdk_config>;
    using transport_tls = autobahn::wamp_websocketpp_websocket_transport<websocketpp_gdk_tls_config>;
    using context_ptr = websocketpp::lib::shared_ptr<boost::asio::ssl::context>;
    using wamp_call_result = boost::future<autobahn::wamp_call_result>;
    using wamp_session_ptr = std::shared_ptr<autobahn::wamp_session>;

    struct event_loop_controller {
        explicit event_loop_controller(boost::asio::io_service& io);

        ~event_loop_controller();

        std::thread m_run_thread;
        std::unique_ptr<boost::asio::io_service::work> m_work_guard;
    };

    class ga_session final {
    public:
        using transport_t = boost::variant<std::shared_ptr<transport>, std::shared_ptr<transport_tls>>;

        ga_session(const network_parameters& net_params, const std::string& proxy, bool use_tor, bool debug);
        ga_session(const ga_session& other) = delete;
        ga_session(ga_session&& other) noexcept = delete;
        ga_session& operator=(const ga_session& other) = delete;
        ga_session& operator=(ga_session&& other) noexcept = delete;

        ~ga_session();

        void connect();
        void reset();
        void register_user(const std::string& mnemonic, const std::string& user_agent);
        void register_user(const std::string& master_pub_key_hex, const std::string& master_chain_code_hex,
            const std::string& gait_path_hex, const std::string& user_agent);

        std::string get_challenge(const std::string& address);
        void authenticate(const std::string& sig_der_hex, const std::string& path_hex, const std::string& device_id,
            const std::string& user_agent, const nlohmann::json& hw_device = nlohmann::json());
        void register_subaccount_xpubs(const std::vector<std::string>& bip32_xpubs);

        void login(const std::string& mnemonic, const std::string& user_agent);
        void login(const std::string& mnemonic, const std::string& password, const std::string& user_agent);
        void login_with_pin(const std::string& pin, const nlohmann::json& pin_data, const std::string& user_agent);
        void login_watch_only(const std::string& username, const std::string& password, const std::string& user_agent);

        bool set_watch_only(const std::string& username, const std::string& password);
        bool remove_account(const nlohmann::json& twofactor_data);

        template <typename T>
        void change_settings(const std::string& key, const T& value, const nlohmann::json& twofactor_data);
        void change_settings_limits(const nlohmann::json& limit_details, const nlohmann::json& twofactor_data);

        nlohmann::json get_transactions(uint32_t subaccount, uint32_t page_id);

        void set_notification_handler(GA_notification_handler handler, void* context);

        nlohmann::json get_subaccounts() const;
        nlohmann::json get_subaccount(uint32_t subaccount) const;
        nlohmann::json create_subaccount(const nlohmann::json& details);
        nlohmann::json get_receive_address(uint32_t subaccount, const std::string& addr_type) const;
        nlohmann::json get_balance(uint32_t subaccount, uint32_t num_confs) const;
        nlohmann::json get_available_currencies() const;
        bool is_rbf_enabled() const;
        bool is_watch_only() const;
        uint32_t get_current_subaccount();
        void set_current_subaccount(uint32_t subaccount);
        const std::string& get_default_address_type() const;

        nlohmann::json get_twofactor_config(bool reset_cached = false);
        std::vector<std::string> get_all_twofactor_methods();
        std::vector<std::string> get_enabled_twofactor_methods();

        void set_email(const std::string& email, const nlohmann::json& twofactor_data);
        void activate_email(const std::string& code);
        void init_enable_twofactor(
            const std::string& method, const std::string& data, const nlohmann::json& twofactor_data);
        void enable_twofactor(const std::string& method, const std::string& code);
        void enable_gauth(const std::string& code, const nlohmann::json& twofactor_data);
        void disable_twofactor(const std::string& method, const nlohmann::json& twofactor_data);
        void twofactor_request_code(
            const std::string& method, const std::string& action, const nlohmann::json& twofactor_data);
        nlohmann::json reset_twofactor(const std::string& email);
        nlohmann::json confirm_twofactor_reset(
            const std::string& email, bool is_dispute, const nlohmann::json& twofactor_data);
        nlohmann::json cancel_twofactor_reset(const nlohmann::json& twofactor_data);

        nlohmann::json set_pin(const std::string& mnemonic, const std::string& pin, const std::string& device_id);

        nlohmann::json get_unspent_outputs(uint32_t subaccount, uint32_t num_confs);
        nlohmann::json get_unspent_outputs_for_private_key(
            const std::string& private_key, const std::string& password, uint32_t unused);
        nlohmann::json get_transaction_details(const std::string& txhash) const;

        nlohmann::json send_transaction(const nlohmann::json& details, const nlohmann::json& twofactor_data);

        void send_nlocktimes();

        void set_transaction_memo(const std::string& txhash_hex, const std::string& memo, const std::string& memo_type);

        void change_settings_pricing_source(const std::string& currency, const std::string& exchange);

        nlohmann::json get_fee_estimates();

        std::string get_mnemonic_passphrase(const std::string& password);

        std::string get_system_message();
        void ack_system_message(const std::string& message);

        nlohmann::json convert_amount(const nlohmann::json& amount_json) const;
        nlohmann::json convert_fiat_cents(amount::value_type fiat_cents) const;

        nlohmann::json encrypt(const nlohmann::json& input_json) const;
        nlohmann::json decrypt(const nlohmann::json& input_json) const;

        amount get_min_fee_rate() const { return amount(m_min_fee_rate); }
        uint32_t get_block_height() const { return m_block_height; }
        bool have_subaccounts() const { return m_subaccounts.size() != 1u; }
        amount get_dust_threshold() const;
        nlohmann::json get_spending_limits() const;
        bool is_spending_limits_decrease(const nlohmann::json& limit_details);
        const network_parameters& get_network_parameters() const { return m_net_params; }

        signer& get_signer();
        ga_pubkeys& get_ga_pubkeys();
        ga_user_pubkeys& get_user_pubkeys();
        ga_user_pubkeys& get_recovery_pubkeys();

    private:
        void set_enabled_twofactor_methods(nlohmann::json& config);
        void update_login_data(nlohmann::json&& login_data, bool watch_only);
        void update_fiat_rate(const std::string& rate_str) const;
        void update_spending_limits(const nlohmann::json& details);

        autobahn::wamp_subscription subscribe(const std::string& topic, const autobahn::wamp_event_handler& callback);
        void call_notification_handler(nlohmann::json* details);

        void on_subaccount_changed(uint32_t subaccount);
        void on_new_transaction(nlohmann::json&& details);
        void on_new_block(nlohmann::json&& details);
        void on_new_fees(nlohmann::json&& details);

        nlohmann::json insert_subaccount(uint32_t subaccount, const std::string& name, const std::string& receiving_id,
            const std::string& recovery_pub_key, const std::string& recovery_chain_code, const std::string& type,
            amount satoshi, bool has_txs);

        std::pair<std::string, std::string> sign_challenge(const std::string& challenge);

        nlohmann::json set_fee_estimates(const nlohmann::json& fee_estimates);

        bool connect_with_tls() const;

        context_ptr tls_init_handler_impl();

        template <typename T> std::enable_if_t<std::is_same<T, client>::value> set_tls_init_handler();
        template <typename T> std::enable_if_t<std::is_same<T, client_tls>::value> set_tls_init_handler();
        template <typename T> void make_client();
        template <typename T> void make_transport();

        template <typename T> void disconnect_transport() const
        {
            no_std_exception_escape([this] { boost::get<std::shared_ptr<T>>(m_transport)->disconnect().get(); });
        }

        void disconnect();
        void unsubscribe();

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

        template <typename F> void no_std_exception_escape(F&& fn) const
        {
            try {
                fn();
            } catch (const std::exception& e) {
                try {
                    const auto what = e.what();
                    GDK_LOG_SEV(log_level::debug) << "ignoring exception:" << what;
                } catch (const std::exception&) {
                }
            }
        }

        std::vector<unsigned char> get_pin_password(const std::string& pin, const std::string& pin_identifier);

        const network_parameters m_net_params;
        const std::string m_proxy;
        const bool m_use_tor;

        boost::asio::io_service m_io;
        boost::variant<std::unique_ptr<client>, std::unique_ptr<client_tls>> m_client;
        transport_t m_transport;
        wamp_session_ptr m_session;
        std::vector<autobahn::wamp_subscription> m_subscriptions;

        event_loop_controller m_controller;

        GA_notification_handler m_notification_handler;
        void* m_notification_context;

        nlohmann::json m_login_data;
        std::vector<unsigned char> m_local_encryption_password;
        std::array<uint32_t, 32> m_gait_path;
        nlohmann::json m_limits_data;
        nlohmann::json m_twofactor_config;
        std::string m_mnemonic;
        amount::value_type m_min_fee_rate;
        std::string m_fiat_source;
        mutable std::string m_fiat_rate;
        std::string m_fiat_currency;
        uint32_t m_current_subaccount;
        uint64_t m_earliest_block_time;

        mutable std::map<uint32_t, nlohmann::json> m_subaccounts; // Includes 0 for main
        std::unique_ptr<ga_pubkeys> m_ga_pubkeys;
        std::unique_ptr<ga_user_pubkeys> m_user_pubkeys;
        std::unique_ptr<ga_user_pubkeys> m_recovery_pubkeys;
        uint32_t m_next_subaccount;
        std::vector<uint32_t> m_fee_estimates;
        std::atomic<uint32_t> m_block_height;
        std::unique_ptr<signer> m_signer;

        uint32_t m_system_message_id; // Next system message
        uint32_t m_system_message_ack_id; // Currently returned message id to ack
        std::string m_system_message_ack; // Currently returned message to ack
        bool m_watch_only;
        bool m_is_locked;
        const boost::asio::ssl::rfc2818_verification m_rfc2818_verifier;
        bool m_cert_pin_validated;
        bool m_debug;
    };

} // namespace sdk
} // namespace ga

#endif
