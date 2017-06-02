#include <stdlib.h>

#include "argparser.h"
#include "session.h"

const char* DEFAULT_MNEMONIC
    = "believe roast zen poorer tax chicken snap calm override french banner salmon bird sad smart ";

int main(int argc, char* argv[])
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    int ret = GA_OK;

    struct GA_session* session = NULL;
    ret = GA_create_session(&session);

    ret = GA_connect(session, options->testnet ? GA_NETWORK_TESTNET : GA_NETWORK_LOCALTEST, GA_FALSE);
    ret = GA_register_user(session, DEFAULT_MNEMONIC);
    ret = GA_login(session, DEFAULT_MNEMONIC);
    ret = GA_change_settings_privacy_send_me(session, GA_ADDRBOOK);
    ret = GA_change_settings_privacy_show_as_sender(session, GA_MUTUAL_ADDRBOOK);
    ret = GA_change_settings_tx_limits(session, 1, 2, 3);

    GA_destroy_session(session);

    return ret;
}
