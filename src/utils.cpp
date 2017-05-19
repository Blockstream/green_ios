#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <array>
#include <functional>
#include <memory>

#include "assertion.hpp"
#include "utils.hpp"

namespace ga {
namespace sdk {

    void get_random_bytes(void* data, std::size_t siz)
    {
        // FIXME: check Core code.
        int random_device = open("/dev/urandom", O_RDONLY);
        GA_SDK_RUNTIME_ASSERT(random_device != -1);
        auto random_device_ptr
            = std::unique_ptr<int, std::function<void(int*)>>(&random_device, [](int* device) { ::close(*device); });

        GA_SDK_RUNTIME_ASSERT(read(random_device, data, siz) == siz);
    }
}
}
