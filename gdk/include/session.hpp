#ifndef GA_SDK_SESSION_HPP
#define GA_SDK_SESSION_HPP
#pragma once

#include <json.hpp>
#include <memory>

#include "common.h"

#include "amount.hpp"
#include "ga_wally.hpp"
#include "network_parameters.hpp"

namespace ga {
namespace sdk {
    class ga_session;

    namespace address_type {
        GASDK_API extern const std::string p2sh;
        GASDK_API extern const std::string p2wsh; // Actually p2sh-p2wsh
        GASDK_API extern const std::string csv;
    }; // namespace address_type

    class GASDK_API session {
    public:
        using address_amount_pair = std::pair<std::string, amount>;

        session();
        ~session();

        session(const session&) = delete;
        session(session&&) = delete;

        session& operator=(const session&) = delete;
        session& operator=(session&&) = delete;

        void connect(const std::string& name, const std::string& proxy = std::string(), bool use_tor = false,
            bool debug = false);
        void connect(const network_parameters& net_params, const std::string& proxy = std::string(),
            bool use_tor = false, bool debug = false);
        void disconnect();

        void register_user(const std::string& mnemonic, const std::string& user_agent = std::string());
        void login(const std::string& mnemonic, const std::string& password = std::string(),
            const std::string& user_agent = std::string());
        void login_with_pin(
            const std::string& pin, const nlohmann::json& pin_data, const std::string& user_agent = std::string());
        void login_watch_only(
            const std::string& username, const std::string& password, const std::string& user_agent = std::string());
        bool set_watch_only(const std::string& username, const std::string& password);
        bool remove_account(const nlohmann::json& twofactor_data);

        // FIXME: recovery_mnemonic requires secure clear.
        nlohmann::json create_subaccount(const nlohmann::json& details);
        nlohmann::json get_subaccounts() const;

        void change_settings_tx_limits(bool is_fiat, uint32_t total, const nlohmann::json& twofactor_data);
        void change_settings_pricing_source(const std::string& currency, const std::string& exchange);

        nlohmann::json get_transactions(uint32_t subaccount, uint32_t page_id);

        void subscribe(const std::string& topic, std::function<void(const std::string& output)> callback);
        void set_notification_handler(GA_notification_handler handler, void* context);

        nlohmann::json get_receive_address(uint32_t subaccount, const std::string& addr_type = std::string());

        nlohmann::json get_subaccounts();

        nlohmann::json get_balance(uint32_t subaccount, uint32_t num_confs);

        nlohmann::json get_available_currencies();

        bool is_rbf_enabled();
        bool is_watch_only();
        std::string get_default_address_type();

        nlohmann::json get_twofactor_config();
        std::vector<std::string> get_all_twofactor_methods();
        std::vector<std::string> get_enabled_twofactor_methods();

        void set_email(const std::string& email, const nlohmann::json& twofactor_data);
        void activate_email(const std::string& code);
        void init_enable_twofactor(
            const std::string& method, const std::string& data, const nlohmann::json& twofactor_data);
        void enable_gauth(const std::string& code, const nlohmann::json& twofactor_data);
        void enable_twofactor(const std::string& method, const std::string& code);
        void disable_twofactor(const std::string& method, const nlohmann::json& twofactor_data);
        void twofactor_request_code(
            const std::string& method, const std::string& action, const nlohmann::json& twofactor_data);
        nlohmann::json reset_twofactor(const std::string& email);
        nlohmann::json confirm_twofactor_reset(
            const std::string& email, bool is_dispute, const nlohmann::json& twofactor_data);
        nlohmann::json cancel_twofactor_reset(const nlohmann::json& twofactor_data);

        nlohmann::json set_pin(const std::string& mnemonic, const std::string& pin, const std::string& device);

        nlohmann::json get_unspent_outputs(uint32_t subaccount, uint32_t num_confs);
        nlohmann::json get_unspent_outputs_for_private_key(
            const std::string& private_key, const std::string& password, uint32_t unused);
        nlohmann::json get_transaction_details(const std::string& txhash_hex);

        nlohmann::json create_transaction(const nlohmann::json& details);
        nlohmann::json sign_transaction(const nlohmann::json& details);
        nlohmann::json send_transaction(const nlohmann::json& details, const nlohmann::json& twofactor_data);

        void send_nlocktimes();

        void set_transaction_memo(const std::string& txhash_hex, const std::string& memo, const std::string& memo_type);

        nlohmann::json get_fee_estimates();

        std::string get_mnemonic_passphrase(const std::string& password);

        std::string get_system_message();
        void ack_system_message(const std::string& system_message);

        nlohmann::json convert_amount(const nlohmann::json& amount_json);
        nlohmann::json encrypt(const nlohmann::json& input_json);
        nlohmann::json decrypt(const nlohmann::json& input_json);

        // FIXME: make this an internal function
        std::vector<unsigned char> output_script(uint32_t subaccount, const nlohmann::json& data) const;
        amount get_min_fee_rate() const;
        bool have_subaccounts() const;
        uint32_t get_block_height() const;
        amount get_dust_threshold() const;
        nlohmann::json get_spending_limits() const;
        void sign_input(const wally_tx_ptr& tx, uint32_t index, const nlohmann::json& u) const;
        nlohmann::json send(const nlohmann::json& details, const nlohmann::json& twofactor_data);

    private:
        template <typename F, typename... Args> auto exception_wrapper(F&& f, Args&&... args);

        GA_notification_handler m_notification_handler;
        void* m_notification_context;

        std::unique_ptr<ga_session> m_impl;
    };
} // namespace sdk
} // namespace ga

#endif
