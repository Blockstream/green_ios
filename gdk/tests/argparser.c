#include <unistd.h>

#include "argparser.h"

int parse_cmd_line_arguments(int argc, char* argv[], struct options** options)
{
    static struct options opts;

    opts.quiet = 0;
    opts.network = "testnet";
    opts.testnet = 1;

    int c;
    while ((c = getopt(argc, argv, "lrq")) != -1) {
        switch (c) {
        default:
            break;
        case 'q':
            opts.quiet = 1;
            break;
        case 'r':
            opts.network = "regtest";
            opts.testnet = 0;
            break;
        case 'l':
            opts.network = "localtest";
            opts.testnet = 0;
            break;
        }
    }

    *options = &opts;

    return 0;
}
