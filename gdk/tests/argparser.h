#ifndef GA_SDK_TESTS_ARGPARSER_H
#define GA_SDK_TESTS_ARGPARSER_H
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct options {
    int quiet;
    int testnet;
};

int parse_cmd_line_arguments(int argc, char* argv[], struct options** options);

#ifdef __cplusplus
}
#endif

#endif
