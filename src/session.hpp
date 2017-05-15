#ifndef GA_SDK_SESSION_HPP
#define GA_SDK_SESSION_HPP
#pragma once

#include <memory>

#include <autobahn/wamp_event_handler.hpp>

#include "network_parameters.hpp"

namespace ga {
namespace sdk {

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

        void register_user(const std::string& mnemonic, const std::string& user_agent);
        void login(const std::string& mnemonic, const std::string& user_agent);

        template <typename... Args> constexpr void change_settings(settings key, Args&&... args)
        {
            change_settings_helper(key, ga::sdk::make_map_from_args(std::forward<Args>(args)...));
        }
        void change_settings(settings key, const std::map<int, int>& args) { change_settings_helper(key, args); }
        void subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler);

    private:
        void change_settings_helper(settings key, const std::map<int, int>& args);

    private:
        class session_impl;
        std::shared_ptr<session_impl> _impl;
    };
}
}

#endif
