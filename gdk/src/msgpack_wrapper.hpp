#ifndef GA_SDK_MSGPACK_WRAPPER_HPP
#define GA_SDK_MSGPACK_WRAPPER_HPP
#pragma once

#if __clang__
#pragma clang diagnostic push
#else
#pragma GCC diagnostic push
#if __GNUC__ > 7
#pragma GCC diagnostic ignored "-Wclass-memaccess"
#endif
#endif

#include <msgpack.hpp>

#if __clang__
#pragma clang diagnostic pop
#else
#pragma GCC diagnostic pop
#endif

#endif
