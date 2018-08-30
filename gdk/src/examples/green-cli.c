/**
 * gagdk
 *
 * Simple command line interface to gdk
 * Currently runs against a fixed (test user) mnemonic on local regtest
 *
 * example:
 *
 * $ gagdk set_email "foo@bar.com"
 * $ gagdk enable-sms
 * $ gagdk change-limits 2000
 */

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "src/common.h"
#include "src/session.h"
#include "src/utils.h"

#include "src/twofactor.h"

/* TODO: allow mnemonic to be specified */
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

/* Dumb mechanism for reading input from console */
#define MAXLEN 1024
static char buf[MAXLEN];
static const char* rawinput()
{
    const char* retval = fgets(buf, MAXLEN, stdin);
    if (retval == NULL) {
        exit(-1);
    }
    if (buf[strlen(buf) - 1] == '\n') {
        buf[strlen(buf) - 1] = '\0';
    }
    return strdup(buf); /* leaks */
}

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
        printf("Please select 2fa factor\n");
        struct GA_twofactor_factor* option;
        for (size_t i = 0; i < factor_count; ++i) {
            const char* type;
            CALL(GA_twofactor_factor_list_get_factor(factors, i, &option))
            CALL(GA_twofactor_factor_type(option, &type))
            printf("%li) %s\n", i, type);
        }
        printf("? ");
        int selection = atoi(rawinput());
        CALL(GA_twofactor_factor_list_get_factor(factors, selection, &selected))
    }
    return selected;
}

/* Prompt user at console for 2fa code */
const char* _user_get_code(const struct GA_twofactor_factor* factor)
{
    const char* type;
    CALL(GA_twofactor_factor_type(factor, &type))
    printf("Please enter 2fa code sent via %s: ", type);
    return rawinput();
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

void change_tx_limits(struct GA_session* session, const char* total)
{
    printf("Setting tx limit (total, BTC) to %s\n", total);
    CALL_2FA(GA_twofactor_change_tx_limits(session, total, &call));
}

void getreceiveaddress(struct GA_session* session)
{
    char* address;
    CALL(GA_get_receive_address(session, 0, GA_ADDRESS_TYPE_P2WSH, &address));
    printf("%s\n", address);
}

void getbalance(struct GA_session* session)
{
    struct GA_balance* balance;
    CALL(GA_get_balance(session, 0, 0, &balance));
    char* json;
    CALL(GA_convert_balance_to_json(balance, &json));
    printf("%s\n", json);
    CALL(GA_destroy_balance(balance));
}

void send(struct GA_session* session, const char* address, const char* amount)
{
    const char* addresses[] = { address };
    uint64_t amount_ = atoi(amount);
    uint64_t amounts[] = { amount_ };
    CALL_2FA(GA_twofactor_send(session, addresses, 1, amounts, 1, 200, 0, &call));
}

int main(int argc, char* argv[])
{
    struct GA_session* session = NULL;
    CALL(GA_create_session(&session))

    /* TODO: currently fixed as local regtest */
    CALL(GA_connect(session, GA_NETWORK_LOCALTEST, 0))
    CALL(GA_register_user(session, DEFAULT_MNEMONIC))

    struct GA_login_data* login_data = NULL;
    CALL(GA_login(session, DEFAULT_MNEMONIC, &login_data))

    assert(argc > 1);
    const char* action = argv[1];
    if (strcmp(action, "2fa") == 0) {
        assert(argc > 2);
        const char* subaction = argv[2];
        if (strcmp(subaction, "set-email") == 0) {
            set_email(session, argv[3]);
        } else if (strcmp(subaction, "enable") == 0) {
            const char* data = argc > 4 ? argv[4] : "";
            twofactor_enable(session, argv[3], data);
        } else if (strcmp(subaction, "disable") == 0) {
            twofactor_disable(session, argv[3]);
        } else if (strcmp(subaction, "get-config") == 0) {
            get_2fa_config(session);
        } else {
            printf("Unknown 2fa subaction: %s\n", subaction);
        }
    } else if (strcmp(action, "change-limits") == 0) {
        change_tx_limits(session, argv[2]);
    } else if (strcmp(action, "get-address") == 0) {
        getreceiveaddress(session);
    } else if (strcmp(action, "get-balance") == 0) {
        getbalance(session);
    } else if (strcmp(action, "send") == 0) {
        send(session, argv[2], argv[3]);
    } else {
        printf("Unknown action: %s\n", action);
    }

    GA_destroy_login_data(login_data);
    GA_destroy_session(session);

    return GA_OK;
}
