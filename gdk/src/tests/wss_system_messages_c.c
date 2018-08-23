#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "argparser.h"
#include "json.h"

#include "src/common.h"
#include "src/session.h"
#include "src/utils.h"

const char* DEFAULT_MNEMONIC = "tragic transfer mesh camera fish model bleak lumber never capital animal era "
                               "coffee shift flame across pitch pipe shiver castle crawl noble obtain response";

uint32_t json_extract_u(const char* json, const char* field_name, uint32_t default_value)
{
    uint32_t result = default_value;
    char* str = json_extract(json, field_name);
    if (str) {
        result = strtoul(str, 0, 10);
        free(str);
    }
    return result;
}

int main(int argc, char* argv[])
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    int ret = GA_OK;

    struct GA_session* session = NULL;
    ret = GA_create_session(&session);

    ret = ret == GA_OK ? GA_connect(session, options->testnet ? GA_NETWORK_TESTNET : GA_NETWORK_LOCALTEST, 0) : ret;
    ret = ret == GA_OK ? GA_register_user(session, DEFAULT_MNEMONIC) : ret;

    struct GA_login_data* login_data = NULL;
    char* login_data_json = NULL;
    ret = ret == GA_OK ? GA_login(session, DEFAULT_MNEMONIC, &login_data) : ret;
    ret = ret == GA_OK ? GA_convert_login_data_to_json(login_data, &login_data_json) : ret;

    uint32_t next_system_message_id = json_extract_u(login_data_json, "next_system_message_id", 0);

    while (next_system_message_id && ret == GA_OK) {
        const char* message_text = NULL;
        uint32_t this_message_id = next_system_message_id;
        ret = ret == GA_OK ? GA_get_system_message(session, &next_system_message_id, &message_text) : ret;

        if (ret == GA_OK) {
            // Try acking with a munged text it should fail
            const char* munged_text = message_text + 1;
            ret = GA_ack_system_message(session, this_message_id, munged_text);
            ret = ret == GA_OK ? GA_ERROR : GA_OK;
        }

        ret = ret == GA_OK ? GA_ack_system_message(session, this_message_id, message_text) : ret;
        GA_destroy_string(message_text);
    }

    GA_destroy_string(login_data_json);
    GA_destroy_login_data(login_data);
    GA_destroy_session(session);

    return ret;
}
