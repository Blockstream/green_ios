#ifndef GA_SDK_ASSERTION_HPP
#define GA_SDK_ASSERTION_HPP
#pragma once

#include <string>

namespace ga {
namespace sdk {
    void runtime_assert_message(
        bool condition, const std::string& error_message, const char* file, const char* func, const char* line);
}
}

#define GA_SDK_STRINGIFY_(x) #x
#define GA_SDK_STRINGIFY(x) GA_SDK_STRINGIFY_(x)
#define GA_SDK_RUNTIME_ASSERT(condition)                                                                               \
    ga::sdk::runtime_assert_message(condition, std::string(), __FILE__, __func__, GA_SDK_STRINGIFY(__LINE__))
#define GA_SDK_RUNTIME_ASSERT_MSG(condition, error_message)                                                            \
    ga::sdk::runtime_assert_message(condition, error_messsage, __FILE__, __func__, GA_SDK_STRINGIFY(__LINE__))

#endif
