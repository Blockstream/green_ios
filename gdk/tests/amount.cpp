#include <iostream>
#include <string>
#include <vector>

#include "include/amount.hpp"
#include "include/assertion.hpp"

using namespace ga;

int main(int argc, char** argv)
{
    (void)argc;
    (void)argv;
    try {
        const nlohmann::json values = { { "btc", "1.111" }, { "fiat", "2.222" }, { "mbtc", "1111" },
            { "satoshi", 111100000 }, { "ubtc", "1111000" }, { "bits", "1111000" } };

        for (const auto case_ : nlohmann::json::iterator_wrapper(values)) {
            nlohmann::json in = { { case_.key(), case_.value() } };
            nlohmann::json result = sdk::amount::convert(in, "USD", "2");
            for (const auto i : nlohmann::json::iterator_wrapper(values)) {
                const auto& r = result[i.key()];
                const auto& v = values[i.key()];
                GA_SDK_RUNTIME_ASSERT_MSG(r == v, case_.key() + ":" + i.key() + ":" + r.dump() + "->" + v.dump());
            }
        }
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}
