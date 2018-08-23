#ifndef GA_SDK_AUTOBAHN_WRAPPER_HPP
#define GA_SDK_AUTOBAHN_WRAPPER_HPP
#pragma once

#ifdef __ANDROID__
#include <sys/epoll.h>
#undef EPOLL_CLOEXEC
#endif

#if __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wignored-qualifiers"
#endif

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wignored-qualifiers"
#if __GNUC__ > 7
#pragma GCC diagnostic ignored "-Wclass-memaccess"
#endif

#include <autobahn/autobahn.hpp>
#include <autobahn/wamp_session.hpp>
#include <autobahn/wamp_websocketpp_websocket_transport.hpp>

#pragma GCC diagnostic pop

#if __clang__
#pragma clang diagnostic pop
#endif

#include <websocketpp/client.hpp>
#include <websocketpp/config/asio_client.hpp>

#endif
