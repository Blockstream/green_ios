#ifndef GA_SDK_AMOUNT_HPP
#define GA_SDK_AMOUNT_HPP
#pragma once

#include <cstdint>
#include <string>

namespace ga {
namespace sdk {

    class amount final {
    public:
        using value_type = std::int64_t;

        static constexpr value_type coin_value = 100000000;
        static constexpr value_type cent = 1000000;

        amount(value_type v)
            : m_value(v)
        {
        }

        amount(const char* str_value);
        amount(const std::string& str_value)
            : amount(str_value.c_str())
        {
        }

        amount(const amount&) = default;
        amount& operator=(const amount&) = default;

        amount(amount&&) = default;
        amount& operator=(amount&&) = default;

        amount& operator=(value_type v)
        {
            m_value = v;
            return *this;
        }

        amount& operator+=(value_type v)
        {
            m_value += v;
            return *this;
        }

        amount& operator-=(value_type v)
        {
            m_value -= v;
            return *this;
        }

        amount& operator*=(value_type v)
        {
            m_value *= v;
            return *this;
        }

        amount& operator/=(value_type v)
        {
            m_value /= v;
            return *this;
        }

        amount& operator+=(const amount& x)
        {
            m_value += x.m_value;
            return *this;
        }

        amount& operator-=(const amount& y)
        {
            m_value -= y.m_value;
            return *this;
        }

        value_type value() const { return m_value; }

    private:
        value_type m_value;
    };

    inline amount operator+(const amount& x, const amount& y)
    {
        amount r = x;
        r += y;
        return r;
    }

    inline amount operator+(const amount& x, amount::value_type y)
    {
        amount r = x;
        r += y;
        return r;
    }

    inline amount operator+(amount::value_type x, const amount& y)
    {
        amount r = y;
        r += x;
        return r;
    }

    inline amount operator-(const amount& x, const amount& y)
    {
        amount r = x;
        r -= y;
        return r;
    }

    inline amount operator-(const amount& x, amount::value_type y)
    {
        amount r = x;
        r -= y;
        return r;
    }

    inline amount operator-(amount::value_type x, const amount& y)
    {
        amount r{ x };
        r -= y;
        return r;
    }

    inline amount operator*(const amount& x, amount::value_type y)
    {
        amount r = x;
        r *= y;
        return r;
    }

    inline amount operator*(amount::value_type x, const amount& y)
    {
        amount r = y;
        r *= x;
        return r;
    }

    inline amount operator/(const amount& x, amount::value_type y)
    {
        amount r = x;
        r /= y;
        return r;
    }

    inline amount operator/(amount::value_type x, const amount& y)
    {
        amount r = y;
        r /= x;
        return r;
    }

    inline amount operator+(const amount& x) { return x; }

    inline amount operator-(const amount& x) { return amount(-x.value()); }

    inline bool operator==(const amount& x, const amount& y) { return x.value() == y.value(); }

    inline bool operator==(const amount& x, const amount::value_type& y) { return x.value() == y; }

    inline bool operator==(amount::value_type x, const amount& y) { return x == y.value(); }

    inline bool operator!=(const amount& x, const amount& y) { return x.value() != y.value(); }

    inline bool operator!=(const amount& x, const amount::value_type& y) { return x.value() != y; }

    inline bool operator!=(amount::value_type x, const amount& y) { return x != y.value(); }
}
}

#endif
