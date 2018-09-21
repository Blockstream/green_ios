#ifndef GA_SDK_TWOFACTOR_H
#define GA_SDK_TWOFACTOR_H

#include "common.h"
#include "session.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Represents an api method call that requires (potentially) two factor authentication to complete.
 *
 * Methods in the api that require two factor authentication to complete are called by first obtaining
 * a GA_twofactor_call, then introspecting it to determine if 2fa is required and resolving the 2fa
 * if necessary before finally making the actual call. Calls are also chained together so that where
 * multiple calls are required it is transparent to the client.
 *
 * For example, to set the email address on a wallet requires two api calls: twofactor.set_email (which
 * requires 2fa if enabled) and then twofactor.activate_email (which requires 2fa of the address being
 * enabled). This is exposed via GA_twofactor_call so that clients can call:
 *
 * struct GA_twofactor_call* call;
 * GA_twofactor_set_email(session, email_address, &call);
 * resolve_2fa(call);
 * GA_destroy_twofactor_call(call);
 *
 * where the function resolve_2fa is implemented by the client to handle interaction with the user
 * to resolve the two factor authentication as necessary. It will generally take the form:
 *
 * function resolve_2fa(call) -> JSON result
 *     while true:
 *         status = GA_twofactor_get_status(call)
 *         if status["status"] == "error":
 *             throw status["status"]
 *         if status["status"] == "done":
 *             return status["result"]
 *         if status["status"] == "request_code":
 *             method = USER_SELECT_FACTOR(call, status["methods"]);
 *             GA_twofactor_request_code(call, method);
 *         else if status["status"] == "resolve_code":
 *             const char* code = USER_GET_CODE(status["method"]);
 *             GA_twofactor_authorize(call, code);
 *         else if status["status"] == "call":
 *             GA_twofactor_call(call);
 *
 * The functions USER_SELECT_FACTOR and USER_GET_CODE implement the required user interaction and will
 * be specific to the client (e.g. a GUI app will probably show some kind of modal dialog)
 */
struct GA_twofactor_call;

/**
 * Request a two method authentication code be sent from the server
 * @call The call requiring two factor authentication
 * @method The selected two factor method to use
 *
 * For some 2fa method, e.g. gauth, this is a no-op
 */
GASDK_API int GA_twofactor_request_code(struct GA_twofactor_call* call, const char* method);

/**
 * Resolve a required 2fa code for the call
 * @call The call requiring two factor authentication
 * @code The two factor authentication code as sent by the server in response to GA_twofactor_request_code
 *
 * This function should be called with the 2fa code supplied by the user before calling GA_twofactor_call
 */
GASDK_API int GA_twofactor_resolve_code(struct GA_twofactor_call* call, const char* code);

/**
 * Get the status/result of a two factor call.
 *
 * @call Call to get the result from
 * @output Destination for the result
 */
GASDK_API int GA_twofactor_get_status(struct GA_twofactor_call* call, struct GA_json** output);

/**
 * Call a 2fa function
 * @call The call with any two factor authentication already resolved
 *
 * Requires that 2fa has already been resolved. After a successful call to GA_twofactor_call
 * the caller should check the status with GA_twofactor_get_status to determine if authorization
 * was successful or whether further calls need to be made.
 */
GASDK_API int GA_twofactor_call(struct GA_twofactor_call* call);

/**
 * Free a GA_twofactor_call
 * @call Call to free
 */
GASDK_API int GA_destroy_twofactor_call(struct GA_twofactor_call* call);

/**
 * Set the email address for a wallet.
 * @session The server session to use
 *
 * When resolved and passed to GA_twofactor_call will call api methods twofactor.set_email
 * and twofactor.activate_email to complete the operation.
 */
GASDK_API int GA_twofactor_set_email(struct GA_session* session, const char* email, struct GA_twofactor_call** call);

/**
 * Enable a two factor authentication method
 * @session The server session to use
 * @method The method to enable, e.g. "email"
 * @data Method specific data, for example for email is an email address
 */
GASDK_API int GA_twofactor_enable(
    struct GA_session* session, const char* method, const char* data, struct GA_twofactor_call** call);

/**
 * Disable a two factor authentication method
 */
GASDK_API int GA_twofactor_disable(struct GA_session* session, const char* method, struct GA_twofactor_call** call);

/** Change the transaction limit (total, BTC) */
GASDK_API int GA_twofactor_change_tx_limits(
    struct GA_session* session, const char* total, struct GA_twofactor_call** call);

GASDK_API int GA_twofactor_send_transaction(
    struct GA_session* session, const struct GA_json* transaction_details, struct GA_twofactor_call** call);

#ifdef __cplusplus
}
#endif

#endif
