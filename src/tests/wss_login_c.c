#include <stdlib.h>

#include "argparser.h"

#include "common.h"
#include "session.h"

const char* DEFAULT_MNEMONIC = "tragic transfer mesh camera fish model bleak lumber never capital animal era "
                               "coffee shift flame across pitch pipe shiver castle crawl noble obtain response";

int main(int argc, char* argv[])
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    int ret = GA_OK;

    struct GA_session* session = NULL;
    ret = GA_create_session(&session);

    ret = GA_connect(session, options->testnet ? GA_NETWORK_TESTNET : GA_NETWORK_LOCALTEST, 0);
    ret = GA_register_user(session, DEFAULT_MNEMONIC);

    struct GA_login_data* login_data = NULL;
    ret = GA_login(session, DEFAULT_MNEMONIC, &login_data);

    GA_destroy_login_data(login_data);
    GA_destroy_session(session);

    return ret;
}
