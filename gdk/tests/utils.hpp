#ifndef GA_SDK_TEST_ASSERT_THROWS_HPP
#define GA_SDK_TEST_ASSERT_THROWS_HPP
#pragma once

#include "include/assertion.hpp"

template <typename Exception, typename T>
void assert_throws(T&& fn)
{
    bool threw = false;
    try
    {
        fn();
    }
    catch (const Exception& e)
    {
        threw = true;
    }
    GA_SDK_RUNTIME_ASSERT(threw);
}

#endif
