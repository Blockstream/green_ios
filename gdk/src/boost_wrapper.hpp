#ifndef GA_SDK_BOOST_WRAPPER_HPP
#define GA_SDK_BOOST_WRAPPER_HPP
#pragma once

#if __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-constant-out-of-range-compare"
#pragma clang diagnostic ignored "-Wunused-parameter"
#else
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#pragma GCC diagnostic ignored "-Wparentheses"
#endif

#include <boost/algorithm/string.hpp>
#include <boost/algorithm/string/join.hpp>
#include <boost/algorithm/string/predicate.hpp>
#include <boost/asio.hpp>
#include <boost/lexical_cast.hpp>
#include <boost/multiprecision/cpp_int.hpp>
#include <boost/variant.hpp>

#if __clang__
#pragma clang diagnostic pop
#else
#pragma GCC diagnostic pop
#endif

#endif
