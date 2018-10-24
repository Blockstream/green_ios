#ifndef GA_SDK_TEST_UTILS_HPP
#define GA_SDK_TEST_UTILS_HPP
#pragma once

#include <iostream>

#include "argparser.h"
#include "include/session.h"
#include "include/utils.h"
#include "src/assertion.hpp"

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

struct GA_session* create_new_wallet(struct options* options);

std::string get_random_string();
#endif
