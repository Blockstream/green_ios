#include <unistd.h>

#include "argparser.h"

int parse_cmd_line_arguments(int argc, char* argv[], struct options** options)
{
    static struct options opts;

    opts.quiet = 0;
    opts.testnet = 1;

    int c;
    while ((c = getopt(argc, argv, "lq")) != -1) {
        switch (c) {
        default:
            break;
        case 'q':
            opts.quiet = 1;
            break;
        case 'l':
            opts.testnet = 0;
            break;
        }
    }

    *options = &opts;

    return 0;
}
