#include <stdlib.h>

#include "argparser.h"

#include "src/common.h"
#include "src/session.h"

const char* DEFAULT_MNEMONIC = "tragic transfer mesh camera fish model bleak lumber never capital animal era "
                               "coffee shift flame across pitch pipe shiver castle crawl noble obtain response";

int main(int argc, char* argv[])
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    int ret = GA_OK;

    struct GA_session* session = NULL;
    ret = GA_create_session(&session);

    ret = ret == GA_OK ? GA_connect(session, options->testnet ? GA_NETWORK_TESTNET : GA_NETWORK_LOCALTEST, GA_FALSE)
                       : ret;
    ret = ret == GA_OK ? GA_register_user(session, DEFAULT_MNEMONIC) : ret;

    ret = ret == GA_OK ? GA_login(session, DEFAULT_MNEMONIC) : ret;

    ret = ret == GA_OK ? GA_change_settings_privacy_send_me(session, GA_ADDRBOOK) : ret;
    ret = ret == GA_OK ? GA_change_settings_privacy_show_as_sender(session, GA_MUTUAL_ADDRBOOK) : ret;
    GA_json* twofactor;
    ret = ret == GA_OK ? GA_convert_string_to_json("{}", &twofactor) : ret;
    ret = ret == GA_OK ? GA_change_settings_tx_limits(session, 1, 2, 3, twofactor) : ret;

    GA_destroy_session(session);

    return ret;
}
