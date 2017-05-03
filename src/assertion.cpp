#include <stdexcept>

#include "assertion.hpp"

namespace ga {
namespace sdk {
    void runtime_assert(bool condition, const char* file, const char* func, const char* line)
    {
        if (!condition) {
            throw std::runtime_error(std::string("assertion failure: ") + file + ":" + func + ":" + line);
        }
    }
}
}
