#include <cctype>
#include <cstring>
#include <stdexcept>

#include <boost/lexical_cast.hpp>

#include "amount.hpp"

namespace ga {
namespace sdk {

    // convert to internal representation (from Bitcoin Core)
    amount::amount(const std::string& str_value)
    {
        std::string str;
        str.reserve(str_value.size());

        value_type units = 0;
        const char* p = str_value.c_str();
        while (std::isspace(*p) != 0) {
            p++;
        }
        for (; *p != 0; p++) {
            if (*p == '.') {
                p++;
                value_type mult = cent * 10;
                while (std::isdigit(*p) != 0 && (mult > 0)) {
                    units += mult * (*p++ - '0');
                    mult /= 10;
                }
                break;
            }
            if (std::isspace(*p) != 0) {
                break;
            }
            if (std::isdigit(*p) == 0) {
                throw std::invalid_argument(std::string("found non digit in: ") + str_value);
            }
            str.push_back(*p);
        }
        for (; *p != 0; p++) {
            if (std::isspace(*p) == 0) {
                throw std::invalid_argument(std::string("found non space in"));
            }
        }
        if (str.size() > 10) { // guard against 63 bit overflow
            throw std::out_of_range(str_value);
        }
        if (units > coin_value) {
            throw std::out_of_range(str_value);
        }

        const auto whole = boost::lexical_cast<value_type>(str);
        m_value = whole * coin_value + units;
    }
}
}
