#ifndef GA_SDK_SESSION_HPP
#define GA_SDK_SESSION_HPP
#pragma once

#include <ctime>
#include <memory>

#include "amount.hpp"
#include "containers.hpp"
#include "network_parameters.hpp"
#include "utils.hpp"

namespace ga {
namespace sdk {

    enum class address_type : uint32_t { p2sh, p2wsh, csv };

    enum class privacy_send_me : uint32_t {
        private_,
        addrbook,
        public_,
    };

    enum class privacy_show_as_sender : uint32_t { private_, mutual_addrbook, public_ };

    enum class tx_limits : uint32_t { is_fiat, per_tx, total };

    enum class tx_list_sort_by : uint32_t {
        timestamp,
        timestamp_ascending,
        timestamp_descending,
        value,
        value_ascending,
        value_descending,
    };

    enum class twofactor_type : uint32_t {
        email,
        gauth,
        phone,
    };

    enum class subaccount_type : uint32_t { _2of2, _2of3 };

    inline namespace literals {

        constexpr tx_list_sort_by operator""_ts(char c)
        {
            switch (c) {
            default:
                __builtin_unreachable();
            case '+':
                return tx_list_sort_by::timestamp_ascending;
            case '-':
                return tx_list_sort_by::timestamp_descending;
            case ' ':
                return tx_list_sort_by::timestamp;
            }
        }

        constexpr tx_list_sort_by operator""_value(char c)
        {
            switch (c) {
            default:
                __builtin_unreachable();
            case '+':
                return tx_list_sort_by::value_ascending;
            case '-':
                return tx_list_sort_by::value_descending;
            case ' ':
                return tx_list_sort_by::value;
            }
        }
    } // namespace literals

    class session {
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
        login_data login(const std::string& mnemonic, const std::string& user_agent = std::string());
        login_data login(const std::string& pin, const std::pair<std::string, std::string>& pin_identifier_and_secret,
            const std::string& user_agent = std::string());
        login_data login_watch_only(
            const std::string& username, const std::string& password, const std::string& user_agent = std::string());
        bool set_watch_only(const std::string& username, const std::string& password);
        bool remove_account();

        // FIXME: recovery_mnemonic requires secure clear.
        std::pair<std::string, std::string> create_subaccount(
            subaccount_type type, const std::string& name, const std::string& xpub = std::string());

        void change_settings_privacy_send_me(privacy_send_me value);
        void change_settings_privacy_show_as_sender(privacy_show_as_sender value);
        void change_settings_tx_limits(
            bool is_fiat, uint32_t per_tx, uint32_t total, const map_strstr& twofactor_data = {});

        tx_list get_tx_list(uint32_t subaccount, const std::pair<std::time_t, std::time_t>& date_range,
            tx_list_sort_by sort_by = ' '_ts, uint32_t page_id = 0, const std::string& query = std::string());

        tx_list get_tx_list(const std::pair<std::time_t, std::time_t>& date_range, tx_list_sort_by sort_by = ' '_ts,
            uint32_t page_id = 0, const std::string& query = std::string());

        void subscribe(const std::string& topic, std::function<void(const std::string& output)> callback);

        receive_address get_receive_address(uint32_t subaccount, address_type addr_type);

        std::vector<subaccount_details> get_subaccounts();

        balance get_balance(uint32_t num_confs);
        balance get_balance(uint32_t subaccount, uint32_t num_confs);

        available_currencies get_available_currencies();

        bool is_rbf_enabled();
        bool is_watch_only();
        address_type get_default_address_type();

        twofactor_config get_twofactor_config();
        bool set_twofactor(twofactor_type type, const std::string& code, const std::string& proxy_code);

        void set_email(const std::string& email, const map_strstr& twofactor_data);
        void activate_email(const std::string& code);
        void init_enable_twofactor(
            const std::string& method, const std::string& data, const map_strstr& twofactor_data);
        void enable_gauth(const std::string& code, const map_strstr& twofactor_data);
        void enable_twofactor(const std::string& method, const std::string& code);
        void disable_twofactor(const std::string& method, const map_strstr& twofactor_data);

        void twofactor_request_code(const std::string& method, const std::string& action, const map_strstr& data);

        pin_info set_pin(const std::string& mnemonic, const std::string& pin, const std::string& device);

        bool add_address_book_entry(const std::string& address, const std::string& name);
        bool edit_address_book_entry(const std::string& address, const std::string& name);
        void delete_address_book_entry(const std::string& address);

        utxo_set get_utxos(uint32_t num_confs);
        utxo_set get_utxos(uint32_t subaccount, uint32_t num_confs);

        std::string make_raw_tx(const std::vector<std::pair<std::string, amount>>& address_amount,
            const std::vector<utxo>& utxos, amount fee_rate, bool send_all);

        void send(const std::string& tx_hex, const map_strstr& twofactor_data = {});
        void send(const std::vector<std::pair<std::string, amount>>& address_amount, const std::vector<utxo>& utxos,
            amount fee_rate, bool send_all, const map_strstr& twofactor_data = {});
        void send(const std::vector<std::pair<std::string, amount>>& address_amount, amount fee_rate, bool send_all,
            const map_strstr& twofactor_data = {});
        void send(uint32_t subaccount, const std::vector<std::pair<std::string, amount>>& address_amount,
            amount fee_rate, bool send_all, const map_strstr& twofactor_data = {});

        void set_transaction_memo(const std::string& txhash_hex, const std::string& memo, const std::string& memo_type);

        void set_pricing_source(const std::string& currency, const std::string& exchange);

        system_message get_system_message(uint32_t system_message_id);
        void ack_system_message(uint32_t system_message_id, const std::string& system_message);

    private:
        template <typename F, typename... Args> auto exception_wrapper(F&& f, Args&&... args);

    private:
        class session_impl;
        std::unique_ptr<session_impl> m_impl;
    };
} // namespace sdk
} // namespace ga

#endif
