#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "argparser.h"

#include "src/common.h"
#include "src/session.h"
#include "src/utils.h"

const char* DEFAULT_MNEMONIC = "tragic transfer mesh camera fish model bleak lumber never capital animal era "
                               "coffee shift flame across pitch pipe shiver castle crawl noble obtain response";

int main(int argc, char* argv[])
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    int ret = GA_OK;

    struct GA_session* session = NULL;
    ret = GA_create_session(&session);

    ret = ret == GA_OK ? GA_connect(session, options->testnet ? GA_NETWORK_TESTNET : GA_NETWORK_LOCALTEST, 0) : ret;
    ret = ret == GA_OK ? GA_register_user(session, DEFAULT_MNEMONIC) : ret;
    ret = ret == GA_OK ? GA_login(session, DEFAULT_MNEMONIC) : ret;

    char* message_text = NULL;

    while ((ret = GA_get_system_message(session, &message_text)) == GA_OK && *message_text) {
        // Fetching the message again should return the same message
        char* same_text = NULL;
        ret = GA_get_system_message(session, &same_text);
        if (ret == GA_OK) {
            ret = strcmp(message_text, same_text) ? GA_ERROR : GA_OK;
            GA_destroy_string(same_text);
        }

        // Try acking with a munged text: it should fail
        char* munged_text = message_text + 1;
        ret = ret == GA_OK ? GA_ack_system_message(session, munged_text) : ret;
        ret = ret == GA_OK ? GA_ERROR : GA_OK;

        // Acking the correct message should succeed
        ret = ret == GA_OK ? GA_ack_system_message(session, message_text) : ret;
        GA_destroy_string(message_text);
    }

    if (ret == GA_OK)
        GA_destroy_string(message_text);
    GA_destroy_session(session);

    return ret;
}
