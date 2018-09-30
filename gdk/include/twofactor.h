#ifndef GA_SDK_TWOFACTOR_H
#define GA_SDK_TWOFACTOR_H

#include "common.h"
#include "session.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Methods in the api that may require two factor authentication to complete
 * return a GA_twofactor_call object. This object encapsulates the process of
 * determining whether two factor authentication is required and handling
 * conditions such as re-prompting and re-trying after an incorrect two
 * factor code is entered.
 *
 * The object acts as a state machine which is stepped through by the caller
 * until the desired action is completed. At each step, the current state can
 * be determined and used to perform the next action required.
 *
 * Some actions require a sequence of codes and decisions; these are hidden
 * behind the state machine interface so that callers do not need to handle
 * special cases or program their own logic to handle any lower level API
 * differences.
 *
 * Example psuedo code to iterate through the state machine is:
 *
 * function resolve_2fa(call) -> JSON result
 *     while true:
 *         status = GA_twofactor_get_status(call)
 *         status_text = status["status"]
 *         if status_text == "error":
 *             GA_destroy_twofactor_call(call);
 *             throw status["error"]
 *         else if status_text == "done":
 *             GA_destroy_twofactor_call(call);
 *             return status["result"]
 *         else if status_text == "request_code":
 *             method = USER_SELECT_METHOD(call, status["methods"]);
 *             GA_twofactor_request_code(call, method);
 *         else if status_text == "resolve_code":
 *             const char* code = USER_GET_CODE(status["method"]);
 *             GA_twofactor_authorize(call, code);
 *         else if status_text == "call":
 *             GA_twofactor_call(call);
 *
 * The functions USER_SELECT_METHOD and USER_GET_CODE must be implemented by
 * the caller as follows:
 * - USER_SELECT_METHOD: Given a list of two factor authentication methods,
 *   allow the user to select one and return it. In the event that only one
 *   method is present in the list, this call can return it directly without
 *   showing anything to the user.
 * - USER_GET_CODE: Given a single two factor method name, allow the user
 *   to enter the code received and return it.
 *
 * Generally in interactive applications these functions would display some
 * kind of dialog to implement the required user interaction.
 */

/**
 * Get the status/result of a two factor call.
 *
 * @call Call to get the result from
 * @output Destination for the result
 */
GASDK_API int GA_twofactor_get_status(struct GA_twofactor_call* call, GA_json** output);

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
 * Enable or disable a two factor authentication method
 * @session The server session to use
 * @method The two factor method to enable/disable, i.e. "email", "sms", "phone", "gauth"
 * @twofactor_details The two factor method and associated data such as an email address
 * @call Destination for the resulting GA_twofactor_call to perform the action
 */
GASDK_API int GA_change_settings_twofactor(
    struct GA_session* session, const char* method, const GA_json* twofactor_details, struct GA_twofactor_call** call);

/** Change the transaction limit (total, BTC) */
#if 0
GASDK_API int GA_twofactor_change_tx_limits(
    struct GA_session* session, const char* total, struct GA_twofactor_call** call);
#endif

#ifdef __cplusplus
}
#endif

#endif
