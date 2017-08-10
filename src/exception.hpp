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

class reconnect_error : public std::runtime_error {
public:
    reconnect_error() : std::runtime_error("reconnect required") {}
};

}
}

#endif
