#include "containers.hpp"

namespace ga {
namespace sdk {

    amount fee_estimates::get_estimate(bool is_instant, uint32_t block) const
    {
        return { (is_instant ? 75 : 60) * 1000 };
    }
}
}
