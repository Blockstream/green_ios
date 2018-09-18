#include <cctype>
#include <cstring>
#include <stdexcept>

#include <json.hpp>

#include "include/boost_wrapper.hpp"

#include "include/amount.hpp"
#include "include/assertion.hpp"

namespace ga {
namespace sdk {
    // BTC amounts have 8 DP
    using btc_type = boost::multiprecision::number<boost::multiprecision::cpp_dec_float<8>>;
    // Fiat amounts are decimal values with 2 DP
    using fiat_type = boost::multiprecision::number<boost::multiprecision::cpp_dec_float<2>>;
    // Internal calculations are done with 15 DP before rounding
    using conversion_type = boost::multiprecision::number<boost::multiprecision::cpp_dec_float<15>>;

    namespace {
        const conversion_type COIN_VALUE_100("100");
        const conversion_type COIN_VALUE_DECIMAL("100000000");
        const conversion_type COIN_VALUE_DECIMAL_MBTC("100000");
        const conversion_type COIN_VALUE_DECIMAL_UBTC("100");
    } // namespace

    // convert to internal representation (from Bitcoin Core)
    amount::amount(const std::string& str_value)
        : m_value(btc_type(conversion_type(str_value) * COIN_VALUE_DECIMAL).convert_to<value_type>())
    {
    }

    nlohmann::json amount::convert(
        const nlohmann::json& amount_json, const std::string& fiat_currency, const std::string& fiat_rate)
    {
        const auto satoshi_p = amount_json.find("satoshi");
        const auto btc_p = amount_json.find("btc");
        const auto mbtc_p = amount_json.find("mbtc");
        const auto ubtc_p = amount_json.find("ubtc");
        const auto bits_p = amount_json.find("bits");
        const auto fiat_p = amount_json.find("fiat");
        const auto end_p = amount_json.end();
        const int key_count = (satoshi_p != end_p) + (btc_p != end_p) + (mbtc_p != end_p) + (ubtc_p != end_p)
            + (bits_p != end_p) + (fiat_p != end_p);
        GA_SDK_RUNTIME_ASSERT(key_count == 1);

        const conversion_type fr(fiat_rate);
        uint32_t satoshi;

        // Compute satoshi from our input
        if (satoshi_p != end_p) {
            satoshi = *satoshi_p;
        } else if (btc_p != end_p) {
            const std::string btc_str = *btc_p;
            satoshi = amount(btc_str).value();
        } else if (mbtc_p != end_p) {
            const std::string mbtc_str = *mbtc_p;
            satoshi = (amount(mbtc_str) / 1000).value();
        } else if (ubtc_p != end_p || bits_p != end_p) {
            const std::string ubtc_str = *(ubtc_p == end_p ? bits_p : ubtc_p);
            satoshi = (amount(ubtc_str) / 1000000).value();
        } else {
            const std::string fiat_str = *fiat_p;
            const conversion_type btc_decimal = conversion_type(fiat_str) / fr;
            satoshi = (btc_type(btc_decimal) * COIN_VALUE_DECIMAL).convert_to<value_type>();
        }

        // Then compute the other denominations and fiat amount
        const conversion_type satoshi_conv = conversion_type(satoshi);
        const std::string btc = btc_type(satoshi_conv / COIN_VALUE_DECIMAL).str();
        const std::string mbtc = btc_type(satoshi_conv / COIN_VALUE_DECIMAL_MBTC).str();
        const std::string ubtc = btc_type(satoshi_conv / COIN_VALUE_DECIMAL_UBTC).str();

        const conversion_type fiat_decimal = fr * conversion_type(satoshi) / COIN_VALUE_DECIMAL;
        const std::string fiat = fiat_type(fiat_decimal).str();

        // FIXME: add fixed precision decimal values with trailing 0's, have server return ISO
        // country code and return it so the caller can do locale aware formatting
        return { { "satoshi", satoshi }, { "btc", btc }, { "mbtc", mbtc }, { "ubtc", ubtc }, { "bits", ubtc },
            { "fiat", fiat }, { "fiat_currency", fiat_currency }, { "fiat_rate", fr.str() } };
    }

    nlohmann::json amount::convert_fiat_cents(
        value_type cents, const std::string& fiat_currency, const std::string& fiat_rate)
    {
        const conversion_type fiat_decimal = conversion_type(cents) / COIN_VALUE_100;
        return convert({ { "fiat", fiat_decimal.str() } }, fiat_currency, fiat_rate);
    }

} // namespace sdk
} // namespace ga
