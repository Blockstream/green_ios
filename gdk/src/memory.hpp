#ifndef GA_SDK_MEMORY_HPP
#define GA_SDK_MEMORY_HPP
#pragma once

#include <array>
#include <memory>
#include <new>
#include <vector>

#include <gsl/gsl_util>

namespace ga {
namespace sdk {
    template <typename T, typename U, typename V> inline void init_container(T& dst, const U& arg1, const V& arg2)
    {
        GA_SDK_RUNTIME_ASSERT(arg1.data() && arg2.data());
        GA_SDK_RUNTIME_ASSERT(
            dst.size() == gsl::narrow<typename T::size_type>(arg1.size() + arg2.size())); // No partial fills supported
        std::copy(arg1.begin(), arg1.end(), dst.data());
        std::copy(arg2.begin(), arg2.end(), dst.data() + arg1.size());
    }
} // namespace sdk
} // namespace ga

#endif
