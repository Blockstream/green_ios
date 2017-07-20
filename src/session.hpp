#ifndef GA_SDK_SESSION_HPP
#define GA_SDK_SESSION_HPP
#pragma once

#include <ctime>
#include <memory>

#include "autobahn_wrapper.hpp"
#include <autobahn/wamp_event_handler.hpp>

#include "containers.hpp"
#include "network_parameters.hpp"
#include "utils.hpp"

namespace ga {
namespace sdk {

    enum class address_type : int { p2sh, p2wsh };

    enum class settings : int {
        privacy_send_me,
        privacy_show_as_sender,
        tx_limits,
    };

    enum class privacy_send_me : int {
        private_,
        addrbook,
        public_,
    };

    enum class privacy_show_as_sender : int { private_, mutual_addrbook, public_ };

    enum class tx_limits : int { is_fiat, per_tx, total };

    enum class tx_list_sort_by {
        timestamp,
        timestamp_ascending,
        timestamp_descending,
        value,
        value_ascending,
        value_descending,
    };

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
        explicit session() = default;
        ~session() = default;

        session(const session&) = delete;
        session(session&&) = delete;

        session& operator=(const session&) = delete;
        session& operator=(session&&) = delete;

        void connect(network_parameters params, bool debug = false);
        void disconnect();

        void register_user(const std::string& mnemonic, const std::string& user_agent = std::string());
        login_data login(const std::string& mnemonic, const std::string& user_agent = std::string());

        template <typename... Args> void change_settings(settings key, Args&&... args)
        {
            change_settings_helper(key, ga::sdk::make_map_from_args(std::forward<Args>(args)...));
        }

        tx_list get_tx_list(const std::pair<std::time_t, std::time_t>& date_range, size_t subaccount = 0,
            tx_list_sort_by sort_by = ' '_ts, size_t page_id = 0, const std::string& query = std::string());

        void subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler);

        receive_address get_receive_address(address_type addr_type = address_type::p2wsh, size_t subaccount = 0) const;

    private:
        void change_settings_helper(settings key, const std::map<int, int>& args);

    private:
        class session_impl;
        std::shared_ptr<session_impl> m_impl;
    };
}
}

#endif
