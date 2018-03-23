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

    enum class address_type : uint8_t { p2sh, p2wsh };

    enum class settings : uint8_t {
        privacy_send_me,
        privacy_show_as_sender,
        tx_limits,
    };

    enum class privacy_send_me : uint8_t {
        private_,
        addrbook,
        public_,
    };

    enum class privacy_show_as_sender : uint8_t { private_, mutual_addrbook, public_ };

    enum class tx_limits : uint8_t { is_fiat, per_tx, total };

    enum class tx_list_sort_by : uint8_t {
        timestamp,
        timestamp_ascending,
        timestamp_descending,
        value,
        value_ascending,
        value_descending,
    };

    enum class two_factor_type : uint8_t {
        email,
        gauth,
        phone,
    };

    enum class subaccount_type : uint8_t { _2of2, _2of3 };

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
    }

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
        std::pair<wally_string_ptr, wally_string_ptr> create_subaccount(
            subaccount_type type, const std::string& name, const std::string& xpub = std::string());

        template <typename... Args> void change_settings(settings key, Args&&... args)
        {
            change_settings_helper(key, ga::sdk::make_map_from_args(std::forward<Args>(args)...));
        }

        tx_list get_tx_list(const std::pair<std::time_t, std::time_t>& date_range, size_t subaccount = 0,
            tx_list_sort_by sort_by = ' '_ts, size_t page_id = 0, const std::string& query = std::string());

        void subscribe(const std::string& topic, std::function<void(const std::string& output)> callback);

        receive_address get_receive_address(address_type addr_type = address_type::p2wsh, size_t subaccount = 0);

        std::vector<subaccount> get_subaccounts();

        balance get_balance_for_subaccount(size_t subaccount, size_t num_confs = 0);
        balance get_balance(size_t num_confs = 0);

        available_currencies get_available_currencies();

        bool is_rbf_enabled();

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
            amount fee_rate, bool send_all = false);
        void send(
            const std::vector<std::pair<std::string, amount>>& address_amount, amount fee_rate, bool send_all = false);

    private:
        void change_settings_helper(settings key, const std::map<int, int>& args);

        template <typename F, typename... Args> auto exception_wrapper(F&& f, Args&&... args);

    private:
        class session_impl;
        std::unique_ptr<session_impl> m_impl;
    };
}
}

#endif
