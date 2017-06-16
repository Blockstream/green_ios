#include <stdlib.h>
#include <string.h>

#include "argparser.h"

#include "common.h"
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

    ret = GA_connect(session, options->testnet ? GA_NETWORK_TESTNET : GA_NETWORK_LOCALTEST, 1);
    ret = GA_register_user(session, DEFAULT_MNEMONIC);
    ret = GA_login(session, DEFAULT_MNEMONIC);

    time_t now = time(NULL);
    time_t now_28_days_before = now - 3600 * 24 * 28;

    struct GA_tx_list* txs = NULL;
    ret = GA_get_tx_list(session, now_28_days_before, now, 0, GA_TIMESTAMP_ASCENDING, 0, "", &txs);

    char* fiat_currency = NULL;
    ret = GA_convert_tx_list_path_to_string(txs, "fiat_currency", &fiat_currency);
    if (strcmp(fiat_currency, "USD")) {
        ret = GA_ERROR;
    }

    GA_destroy_tx_list(txs);
    GA_destroy_string(fiat_currency);
    GA_destroy_session(session);

    return ret;
}
