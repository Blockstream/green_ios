#include <stdexcept>
#include <string>

#include "assertion.hpp"

namespace ga {
namespace sdk {
    void runtime_assert_message(
        bool condition, const std::string& error_message, const char* file, const char* func, const char* line)
    {
        if (!condition) {
            throw std::runtime_error(
                std::string("assertion failure: ") + file + ":" + func + ":" + line + ":" + error_message);
        }
    }
}
}
