#ifndef GA_SDK_TESTS_ARGPARSER_H
#define GA_SDK_TESTS_ARGPARSER_H
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

struct options {
    int quiet;
    const char* network;
    int testnet;
};

int parse_cmd_line_arguments(int argc, char* argv[], struct options** options);

#ifdef __cplusplus
}
#endif

#endif
