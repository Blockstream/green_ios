#ifndef GA_SDK_AUTOBAHN_WRAPPER_HPP
#define GA_SDK_AUTOBAHN_WRAPPER_HPP
#pragma once

#ifdef __ANDROID__
#include <sys/epoll.h>
#undef EPOLL_CLOEXEC
#endif

#include <autobahn/autobahn.hpp>
#include <autobahn/wamp_websocketpp_websocket_transport.hpp>

#include <websocketpp/client.hpp>
#include <websocketpp/config/asio_client.hpp>

#endif
