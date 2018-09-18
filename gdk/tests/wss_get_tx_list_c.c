#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "argparser.h"

#include "include/session.h"
#include "include/utils.h"

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

    ret = ret == GA_OK ? GA_login(session, DEFAULT_MNEMONIC) : ret;

    GA_json* txs = NULL;
    ret = ret == GA_OK ? GA_get_transactions(session, 0, 0, &txs) : ret;

    uint32_t next_page_id = 0;
    ret = ret == GA_OK ? GA_convert_json_value_to_uint32(txs, "next_page_id", &next_page_id) : ret;

    char* json_str = NULL;
    ret = ret == GA_OK ? GA_convert_json_to_string(txs, &json_str) : ret;
    if (ret == GA_OK) {
        // printf("\nReturned:\n%s\n", json_str);
        GA_destroy_string(json_str);
    }
    GA_destroy_json(txs);
    GA_destroy_session(session);

    return ret;
}
