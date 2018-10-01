#ifndef GA_SDK_SESSION_HPP
#define GA_SDK_SESSION_HPP
#pragma once

#include <ctime>
#include <memory>

#include "common.h"

#include "amount.hpp"
#include "containers.hpp"
#include "network_parameters.hpp"
#include "utils.hpp"

namespace ga {
namespace sdk {

    enum class address_type : uint32_t {
        p2sh = GA_ADDRESS_TYPE_P2SH,
        p2wsh = GA_ADDRESS_TYPE_P2WSH,
        csv = GA_ADDRESS_TYPE_CSV,
        default_ = GA_ADDRESS_TYPE_DEFAULT
    };

    enum class privacy_send_me : uint32_t {
        private_,
        addrbook,
        public_,
    };

    enum class privacy_show_as_sender : uint32_t { private_, mutual_addrbook, public_ };

    enum class twofactor_type : uint32_t {
        email,
        gauth,
        phone,
    };

    enum class subaccount_type : uint32_t { _2of2, _2of3 };

    class GASDK_API session {
    public:
        using address_amount_pair = std::pair<std::string, amount>;

        session();
        ~session();

        session(const session&) = delete;
        session(session&&) = delete;

        session& operator=(const session&) = delete;
        session& operator=(session&&) = delete;

        void connect(network_parameters params, bool debug = false);
        void disconnect();

        void register_user(const std::string& mnemonic, const std::string& user_agent = std::string());
        void login(const std::string& mnemonic, const std::string& user_agent = std::string());
        void login(
            const std::string& pin, const nlohmann::json& pin_data, const std::string& user_agent = std::string());
        void login_watch_only(
            const std::string& username, const std::string& password, const std::string& user_agent = std::string());
        bool set_watch_only(const std::string& username, const std::string& password);
        bool remove_account(const nlohmann::json& twofactor_data);

        // FIXME: recovery_mnemonic requires secure clear.
        nlohmann::json create_subaccount(const nlohmann::json& details);
        nlohmann::json get_subaccounts() const;

        void change_settings_privacy_send_me(privacy_send_me value);
        void change_settings_privacy_show_as_sender(privacy_show_as_sender value);
        void change_settings_tx_limits(bool is_fiat, uint32_t total, const nlohmann::json& twofactor_data);
        void change_settings_pricing_source(const std::string& currency, const std::string& exchange);

        nlohmann::json get_transactions(uint32_t subaccount, uint32_t page_id);

        void subscribe(const std::string& topic, std::function<void(const std::string& output)> callback);

        nlohmann::json get_receive_address(uint32_t subaccount, address_type addr_type);

        nlohmann::json get_subaccounts();

        nlohmann::json get_balance(uint32_t subaccount, uint32_t num_confs);

        nlohmann::json get_available_currencies();

        bool is_rbf_enabled();
        bool is_watch_only();
        address_type get_default_address_type();

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

        nlohmann::json set_pin(const std::string& mnemonic, const std::string& pin, const std::string& device);

        bool add_address_book_entry(const std::string& address, const std::string& name);
        bool edit_address_book_entry(const std::string& address, const std::string& name);
        void delete_address_book_entry(const std::string& address);

        nlohmann::json get_unspent_outputs(uint32_t subaccount, uint32_t num_confs);
        nlohmann::json get_unspent_outputs_for_private_key(
            const std::string& private_key, const std::string& password, uint32_t unused);
        nlohmann::json get_transaction_details(const std::string& txhash_hex);

        nlohmann::json create_transaction(const nlohmann::json& details);
        nlohmann::json sign_transaction(const nlohmann::json& details);

        nlohmann::json send(const nlohmann::json& details, const nlohmann::json& twofactor_data);

        void send_nlocktimes();

        void set_transaction_memo(const std::string& txhash_hex, const std::string& memo, const std::string& memo_type);

        nlohmann::json get_fee_estimates();

        std::string get_mnemonic_passphrase(const std::string& password);

        std::string get_system_message();
        void ack_system_message(const std::string& system_message);

        nlohmann::json convert_amount(const nlohmann::json& amount_json);
        nlohmann::json encrypt_decrypt(const nlohmann::json& input_json);

    private:
        template <typename F, typename... Args> auto exception_wrapper(F&& f, Args&&... args);

    private:
        class session_impl;
        std::unique_ptr<session_impl> m_impl;
    };
} // namespace sdk
} // namespace ga

#endif
