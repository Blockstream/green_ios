#ifndef GA_SDK_ASSERTION_HPP
#define GA_SDK_ASSERTION_HPP
#pragma once

namespace ga {
namespace sdk {
    void runtime_assert(bool condition, const char* file, const char* func, const char* line);
}
}

#define GA_SDK_STRINGIFY_(x) #x
#define GA_SDK_STRINGIFY(x) GA_SDK_STRINGIFY_(x)
#define GA_SDK_RUNTIME_ASSERT(condition)                                                                               \
    ga::sdk::runtime_assert(condition, __FILE__, __func__, GA_SDK_STRINGIFY(__LINE__))

#endif
