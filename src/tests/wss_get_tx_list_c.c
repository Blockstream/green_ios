#include <stdlib.h>
#include <string.h>

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

    ret = ret == GA_OK ? GA_connect(session, options->testnet ? GA_NETWORK_TESTNET : GA_NETWORK_LOCALTEST, 1) : ret;
    ret = ret == GA_OK ? GA_register_user(session, DEFAULT_MNEMONIC) : ret;

    struct GA_login_data* login_data = NULL;
    ret = ret == GA_OK ? GA_login(session, DEFAULT_MNEMONIC, &login_data) : ret;

    struct GA_tx_list* txs = NULL;
    ret = ret == GA_OK ? GA_get_tx_list(session, 0, 0, 0, GA_TIMESTAMP_ASCENDING, 0, "", &txs) : ret;

    char* fiat_currency = NULL;
    ret = ret == GA_OK ? GA_convert_tx_list_path_to_string(txs, "fiat_currency", &fiat_currency) : ret;
    if (ret != GA_OK || strcmp(fiat_currency, "USD")) {
        ret = GA_ERROR;
    }

    GA_destroy_string(fiat_currency);
    GA_destroy_tx_list(txs);
    GA_destroy_login_data(login_data);
    GA_destroy_session(session);

    return ret;
}
