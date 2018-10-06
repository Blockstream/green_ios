#ifndef GA_SDK_EXCEPTION_HPP
#define GA_SDK_EXCEPTION_HPP
#pragma once

#include <autobahn/exceptions.hpp>

namespace ga {
namespace sdk {

    using abort_error = autobahn::abort_error;
    using network_error = autobahn::network_error;
    using no_session_error = autobahn::no_session_error;
    using no_transport_error = autobahn::no_transport_error;
    using protocol_error = autobahn::protocol_error;

    class login_error : public std::runtime_error {
    public:
        login_error(const std::string& what)
            : std::runtime_error("login failed:" + what)
        {
        }
    };

    class reconnect_error : public std::runtime_error {
    public:
        reconnect_error()
            : std::runtime_error("reconnect required")
        {
        }
    };

    class timeout_error : public std::runtime_error {
    public:
        timeout_error()
            : std::runtime_error("timeout error")
        {
        }
    };
} // namespace sdk
} // namespace ga

#endif
