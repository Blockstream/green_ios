#include <stdlib.h>

#include "argparser.h"

#include "src/common.h"
#include "src/session.h"
#include "src/utils.h"

int main(int argc, char* argv[])
{
    struct options* options;
    GA_json* pin_data = NULL;
    int ret = GA_OK;

    parse_cmd_line_arguments(argc, argv, &options);

    {
        struct GA_session* session = NULL;
        char* mnemonic = NULL;
        ret = ret == GA_OK ? GA_generate_mnemonic("en", &mnemonic) : ret;
        ret = GA_create_session(&session);
        ret = ret == GA_OK ? GA_connect(session, options->testnet ? GA_NETWORK_TESTNET : GA_NETWORK_LOCALTEST, 1) : ret;
        ret = ret == GA_OK ? GA_register_user(session, mnemonic) : ret;
        ret = ret == GA_OK ? GA_login(session, mnemonic) : ret;
        ret = ret == GA_OK ? GA_set_pin(session, mnemonic, "0000", "default", &pin_data) : ret;
        GA_destroy_string(mnemonic);
        GA_destroy_session(session);
    }

    {
        struct GA_session* session = NULL;
        ret = ret == GA_OK ? GA_create_session(&session) : ret;
        ret = ret == GA_OK ? GA_connect(session, options->testnet ? GA_NETWORK_TESTNET : GA_NETWORK_LOCALTEST, 1) : ret;
        ret = ret == GA_OK ? GA_login_with_pin(session, "0000", pin_data) : ret;
        ret = ret == GA_OK ? GA_remove_account(session, NULL) : ret;
        GA_destroy_session(session);
    }

    GA_destroy_json(pin_data);

    return ret;
}
