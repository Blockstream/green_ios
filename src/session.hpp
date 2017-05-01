#ifndef GA_SDK_SESSION_HPP
#define GA_SDK_SESSION_HPP
#pragma once

#include <memory>

#include <autobahn/wamp_event_handler.hpp>

namespace ga {
namespace sdk {

    class session {
    public:
        explicit session() = default;
        ~session() = default;

        session(const session&) = delete;
        session(session&&) = delete;

        session& operator=(const session&) = delete;
        session& operator=(session&&) = delete;

        void connect(const std::string& endpoint, bool debug = false);
        void disconnect();

        void subscribe(const std::string& topic, const autobahn::wamp_event_handler& handler);

    private:
        class session_impl;
        std::shared_ptr<session_impl> _impl;
    };
}
}

#endif
