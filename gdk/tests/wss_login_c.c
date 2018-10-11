#include <stdlib.h>

#include "argparser.h"

#include "include/session.h"

const char* DEFAULT_MNEMONIC = "tragic transfer mesh camera fish model bleak lumber never capital animal era "
                               "coffee shift flame across pitch pipe shiver castle crawl noble obtain response";

int main(int argc, char* argv[])
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    int ret = GA_OK;

    const bool debug = options->quiet == 0;
    struct GA_session* session = NULL;
    ret = GA_create_session(&session);

    ret = ret == GA_OK ? GA_connect(session, options->network, debug) : ret;
    ret = ret == GA_OK ? GA_register_user(session, DEFAULT_MNEMONIC) : ret;

    ret = ret == GA_OK ? GA_login(session, DEFAULT_MNEMONIC, "") : ret;

    GA_destroy_session(session);

    return ret;
}
