#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "argparser.h"
#include "json.h"

#include "src/common.h"
#include "src/session.h"
#include "src/utils.h"

#include "src/twofactor.h"

const char* DEFAULT_MNEMONIC = "tragic transfer mesh camera fish model bleak lumber never capital animal era "
                               "coffee shift flame across pitch pipe shiver castle crawl noble obtain response";

#define CALL(fn)                                                                                                       \
    {                                                                                                                  \
        int ret = fn;                                                                                                  \
        if (ret != GA_OK) {                                                                                            \
            printf("FAIL(%d) line %d: %s\n", ret, __LINE__, #fn);                                                      \
            exit(ret);                                                                                                 \
        }                                                                                                              \
    }

#define CALL_2FA(fn)                                                                                                   \
    {                                                                                                                  \
        struct GA_twofactor_call* call = NULL;                                                                         \
        CALL(fn);                                                                                                      \
        resolve_2fa(call);                                                                                             \
        CALL(GA_destroy_twofactor_call(call));                                                                         \
    }

#define ASSERT(x)                                                                                                      \
    if (!(x)) {                                                                                                        \
        fprintf(stderr, "assertion failed line %d %s\n", __LINE__, #x);                                                \
        exit(-1);                                                                                                      \
    }

/* In test mode there is no interaction, all 2fa codes are fixed as 555555 */
static const char* test_twofactor_code = "555555";
static int test_twofactor_factor_index = 0;

/**
 * Return 2fa config as json string
 */
char* get_2fa_config_(struct GA_session* session)
{
    struct GA_twofactor_config* config = NULL;
    CALL(GA_get_twofactor_config(session, &config))
    char* json;
    CALL(GA_convert_twofactor_config_to_json(config, &json));
    CALL(GA_destroy_twofactor_config(config));
    return json;
}

void get_2fa_config(struct GA_session* session)
{
    printf("Two factor authentication config:\n");
    char* json = get_2fa_config_(session);
    printf("%s\n", json);
    GA_destroy_string(json);
}

/* Prompt user at console to select 2fa factor */
const struct GA_twofactor_factor* _user_select_factor(struct GA_twofactor_call* call)
{
    size_t factor_count;
    struct GA_twofactor_factor* selected = NULL;
    struct GA_twofactor_factor_list* factors = NULL;
    CALL(GA_twofactor_get_factors(call, &factors));
    CALL(GA_twofactor_factor_list_get_size(factors, &factor_count));
    if (factor_count == 1) {
        CALL(GA_twofactor_factor_list_get_factor(factors, 0, &selected))
    } else if (factor_count > 1) {
        CALL(GA_twofactor_factor_list_get_factor(factors, test_twofactor_factor_index, &selected));
    }
    return selected;
}

/* Prompt user at console for 2fa code */
const char* _user_get_code(__attribute__((unused)) const struct GA_twofactor_factor* factor)
{
    return test_twofactor_code;
}

/**
 * Deal with all the 2fa stuff and call the method
 *
 * Some incarnation of this method will need to be implemented in each
 * client, for example in a GUI app it will pop up dialog boxes.
 */
void resolve_2fa(struct GA_twofactor_call* call)
{
    /**
     * If the call requires 2fa get the user to select the factor, request the
     * code and get the code from the user
     */
    const struct GA_twofactor_factor* factor = _user_select_factor(call);
    if (factor) {
        CALL(GA_twofactor_request_code(factor, call))
        CALL(GA_twofactor_resolve_code(call, _user_get_code(factor)))
    }

    /* Make the call */
    CALL(GA_twofactor_call(call))

    /* Resolve the next call (if any) */
    struct GA_twofactor_call* next = 0;
    CALL(GA_twofactor_next_call(call, &next))
    if (next) {
        resolve_2fa(next);
    }
}

void set_email(struct GA_session* session, const char* email)
{
    printf("Setting email to %s\n", email);
    CALL_2FA(GA_twofactor_set_email(session, email, &call));
}

void twofactor_enable(struct GA_session* session, const char* factor, const char* data)
{
    printf("Enabling two factor authentication factor %s:%s\n", factor, data);
    CALL_2FA(GA_twofactor_enable(session, factor, data, &call));
}

void twofactor_disable(struct GA_session* session, const char* factor)
{
    printf("Disabling two factor authentication factor %s\n", factor);
    CALL_2FA(GA_twofactor_disable(session, factor, &call));
}

void assert_twofactor_config(struct GA_session* session, const char* key, const char* value)
{
    char* json = get_2fa_config_(session);
    const char* value_ = json_extract(json, key);
    if (strcmp(value_, value) != 0) {
        fprintf(stderr, "%s != %s\n", value_, value);
        ASSERT(false);
        exit(-1);
    }
}

void test(struct GA_session* session)
{
    twofactor_disable(session, "sms");
    assert_twofactor_config(session, "sms", "false");
    twofactor_enable(session, "sms", "12345678");
    assert_twofactor_config(session, "sms", "true");
    twofactor_disable(session, "sms");
    assert_twofactor_config(session, "sms", "false");

    twofactor_disable(session, "phone");
    assert_twofactor_config(session, "phone", "false");
    twofactor_enable(session, "phone", "12345678");
    assert_twofactor_config(session, "phone", "true");
    twofactor_disable(session, "phone");
    assert_twofactor_config(session, "phone", "false");

    twofactor_disable(session, "gauth");
    assert_twofactor_config(session, "gauth", "false");
    twofactor_enable(session, "gauth", "<ignored>");
    assert_twofactor_config(session, "gauth", "true");
    twofactor_disable(session, "gauth");
    assert_twofactor_config(session, "gauth", "false");

    twofactor_disable(session, "email");
    assert_twofactor_config(session, "email", "false");
    set_email(session, "foo@baz.com");
    assert_twofactor_config(session, "email_confirmed", "true");
    assert_twofactor_config(session, "email_addr", "\"foo@baz.com\"");
    assert_twofactor_config(session, "email", "false");

    twofactor_enable(session, "email", "foo@bar.com");
    assert_twofactor_config(session, "email", "true");
    assert_twofactor_config(session, "email_confirmed", "true");
    assert_twofactor_config(session, "email_addr", "\"foo@bar.com\"");
    twofactor_disable(session, "email");
    assert_twofactor_config(session, "email", "false");
    assert_twofactor_config(session, "email_confirmed", "true");
    assert_twofactor_config(session, "email_addr", "\"foo@bar.com\"");

    set_email(session, "foo@baz.com");
    assert_twofactor_config(session, "email_confirmed", "true");
    assert_twofactor_config(session, "email_addr", "\"foo@baz.com\"");
    assert_twofactor_config(session, "email", "false");
}

int main(int argc, char* argv[])
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    struct GA_session* session = NULL;
    CALL(GA_create_session(&session))

    CALL(GA_connect(session, options->testnet ? GA_NETWORK_TESTNET : GA_NETWORK_LOCALTEST, 0))
    CALL(GA_register_user(session, DEFAULT_MNEMONIC))

    struct GA_login_data* login_data = NULL;
    CALL(GA_login(session, DEFAULT_MNEMONIC, &login_data))

    test(session);

    GA_destroy_login_data(login_data);
    GA_destroy_session(session);

    return GA_OK;
}
