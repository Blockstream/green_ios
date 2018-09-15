#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "argparser.h"

#include "src/common.h"
#include "src/session.h"
#include "src/utils.h"

#include "src/twofactor.h"

const char* DEFAULT_MNEMONIC = "tragic transfer mesh camera fish model bleak lumber never capital animal era "
                               "coffee shift flame across pitch pipe shiver castle crawl noble obtain response";

#define CALL(fn)                                                                                                       \
    {                                                                                                                  \
        if (fn != GA_OK) {                                                                                             \
            printf("FAIL line %d: %s\n", __LINE__, #fn);                                                               \
            abort();                                                                                                   \
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
        abort();                                                                                                       \
    }

/* In test mode there is no interaction, all 2fa codes are fixed as 555555 */
static const char* test_twofactor_code = "555555";
static int test_twofactor_method_index = 0;

/* Prompt user at console to select 2fa factor */
static const struct GA_twofactor_method* _user_select_factor(struct GA_twofactor_call* call)
{
    uint32_t factor_count;
    struct GA_twofactor_method* selected = NULL;
    struct GA_twofactor_method_list* factors = NULL;
    CALL(GA_twofactor_get_methods(call, &factors));
    CALL(GA_twofactor_method_list_get_size(factors, &factor_count));
    if (factor_count == 1) {
        CALL(GA_twofactor_method_list_get_factor(factors, 0, &selected))
    } else if (factor_count > 1) {
        CALL(GA_twofactor_method_list_get_factor(factors, test_twofactor_method_index, &selected));
    }
    return selected;
}

/* Prompt user at console for 2fa code */
static const char* _user_get_code(__attribute__((unused)) const struct GA_twofactor_method* factor)
{
    return test_twofactor_code;
}

/**
 * Deal with all the 2fa stuff and call the method
 *
 * Some incarnation of this method will need to be implemented in each
 * client, for example in a GUI app it will pop up dialog boxes.
 */
static void resolve_2fa(struct GA_twofactor_call* call)
{
    /**
     * If the call requires 2fa get the user to select the factor, request the
     * code and get the code from the user
     */
    const struct GA_twofactor_method* factor = _user_select_factor(call);
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

static void set_email(struct GA_session* session, const char* email)
{
    printf("Setting email to %s\n", email);
    CALL_2FA(GA_twofactor_set_email(session, email, &call));
}

static void twofactor_enable(struct GA_session* session, const char* factor, const char* data)
{
    printf("Enabling two factor authentication factor %s:%s\n", factor, data);
    CALL_2FA(GA_twofactor_enable(session, factor, data, &call));
}

static void twofactor_disable(struct GA_session* session, const char* factor)
{
    printf("Disabling two factor authentication factor %s\n", factor);
    CALL_2FA(GA_twofactor_disable(session, factor, &call));
}

static void assert_json_value(GA_json* json, const char* key, const char* expected, bool is_bool)
{
    char* result;
    if (is_bool) {
        uint32_t b;
        CALL(GA_convert_json_value_to_bool(json, key, &b));
        result = (char*)(b ? "true" : "false");
    } else {
        CALL(GA_convert_json_value_to_string(json, key, &result));
    }
    if (strcmp(result, expected) != 0) {
        fprintf(stderr, "%s != %s\n", result, expected);
        ASSERT(false);
        abort();
    }
    if (!is_bool) {
        GA_destroy_string(result);
    }
}

static void assert_twofactor_config(struct GA_session* session, const char* key, const char* expected, bool is_bool)
{
    GA_json* config = NULL;
    CALL(GA_get_twofactor_config(session, &config))
    assert_json_value(config, key, expected, is_bool);
    GA_destroy_json(config);
}

static void test(struct GA_session* session)
{
    // FIXME: currently fail due to the code being invalid/Needs backend hack

    twofactor_disable(session, "sms");
    assert_twofactor_config(session, "sms", "false", true);
    twofactor_enable(session, "sms", "12345678");
    assert_twofactor_config(session, "sms", "true", true);
    twofactor_disable(session, "sms");
    assert_twofactor_config(session, "sms", "false", true);

    twofactor_disable(session, "phone");
    assert_twofactor_config(session, "phone", "false", true);
    twofactor_enable(session, "phone", "12345678");
    assert_twofactor_config(session, "phone", "true", true);
    twofactor_disable(session, "phone");
    assert_twofactor_config(session, "phone", "false", true);

    twofactor_disable(session, "gauth");
    assert_twofactor_config(session, "gauth", "false", true);
    twofactor_enable(session, "gauth", "<ignored>");
    assert_twofactor_config(session, "gauth", "true", true);
    twofactor_disable(session, "gauth");
    assert_twofactor_config(session, "gauth", "false", true);

    twofactor_disable(session, "email");
    assert_twofactor_config(session, "email", "false", true);
    set_email(session, "foo@baz.com");
    assert_twofactor_config(session, "email_confirmed", "true", true);
    assert_twofactor_config(session, "email_addr", "\"foo@baz.com\"", false);
    assert_twofactor_config(session, "email", "false", true);

    twofactor_enable(session, "email", "foo@bar.com");
    assert_twofactor_config(session, "email", "true", true);
    assert_twofactor_config(session, "email_confirmed", "true", true);
    assert_twofactor_config(session, "email_addr", "\"foo@bar.com\"", false);
    twofactor_disable(session, "email");
    assert_twofactor_config(session, "email", "false", true);
    assert_twofactor_config(session, "email_confirmed", "true", true);
    assert_twofactor_config(session, "email_addr", "\"foo@bar.com\"", false);

    set_email(session, "foo@baz.com");
    assert_twofactor_config(session, "email_confirmed", "true", true);
    assert_twofactor_config(session, "email_addr", "\"foo@baz.com\"", false);
    assert_twofactor_config(session, "email", "false", true);
}

int main(int argc, char* argv[])
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    struct GA_session* session = NULL;
    CALL(GA_create_session(&session))

    CALL(GA_connect(session, options->testnet ? GA_NETWORK_TESTNET : GA_NETWORK_LOCALTEST, 0))
    CALL(GA_register_user(session, DEFAULT_MNEMONIC))

    CALL(GA_login(session, DEFAULT_MNEMONIC))

    test(session);

    GA_destroy_session(session);

    return GA_OK;
}
