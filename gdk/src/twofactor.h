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
 * void resolve_2fa(struct GA_twofactor_call* call)
 * {
 *     GA_twofactor_method* selected_factor = _user_select_factor(call);
 *     if (selected_factor) {
 *         GA_twofactor_request_code(selected_factor, call);
 *         const char* code = _user_get_code();
 *         GA_twofactor_resolve_code(call, code);
 *     }
 *     GA_twofactor_call(call);
 *
 *     const GA_twofactor_call* next;
 *     GA_twofactor_next_call(call, &next);
 *     if (next) {
 *         resolve_2fa(next);
 *     }
 * }
 *
 * The functions _user_select_factor and _user_get_code implement the required user interaction and will
 * be specific to the client (e.g. a GUI app will probably show some kind of modal dialog)
 */
struct GA_twofactor_call;

/** A specific 2fa method
 *
 * For example:
 * - the email address "foo@bar.com"
 * - an sms sent to +44123456
 */
struct GA_twofactor_method;

/**
 * A list of 2fa methods
 */
struct GA_twofactor_method_list;

/**
 * Return the size of a list of 2fa methods
 */
GASDK_API int GA_twofactor_method_list_get_size(struct GA_twofactor_method_list* methods, uint32_t* output);

/**
 * Return a method from a list of 2fa methods
 */
GASDK_API int GA_twofactor_method_list_get_factor(
    struct GA_twofactor_method_list* methods, uint32_t i, struct GA_twofactor_method** output);

/**
 * Return all 2fa methods available for a call
 *
 * If two factor authentication is not enabled or not required for the call the list will be empty.
 *
 * The set of methods will generally be one of:
 * - the set of all methods enabled for the wallet
 * - a single method if the call is confirming that method (e.g. activate_email)
 * - an empty list if 2fa is not enabled, or the call does not require 2fa
 *
 * Clients should:
 * - Do nothing and proceed to call GA_twofactor_call if the list is empty
 * - Offer the user a choice if the list contains more than one method
 * - If either the user selected a method or the list contains only a single method proceed to resolve
 *   2fa by calling GA_twofactor_request_code and GA_twofactor_resolve_code and then GA_twofactor_call.
 */
GASDK_API int GA_twofactor_get_methods(struct GA_twofactor_call* call, struct GA_twofactor_method_list** output);

/**
 * Free a list of 2fa methods returned by GA_twofactor_get_methods
 */
int GA_destroy_twofactor_method_list(struct GA_twofactor_method_list* methods);

/**
 * Return the type of a 2fa method as a utf-8 encoded string
 * @method The 2fa method
 * @type The type as a null-terminated utf-8 encoded string
 *
 * Possible types: 'email', 'sms', 'phone', 'gauth'
 */
GASDK_API int GA_twofactor_method_type(const struct GA_twofactor_method* method, char** type);

/**
 * Request a two method authentication code be sent from the server
 * @method The selected two factor method to use
 * @call The call requiring two factor authentication
 *
 * For some 2fa method, e.g. gauth, this is a no-op
 */
GASDK_API int GA_twofactor_request_code(const struct GA_twofactor_method* method, struct GA_twofactor_call* call);

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
 * the caller should pass the call to GA_twofactor_next_call and proceed to handle the next call
 * (if any) in the same way.
 */
GASDK_API int GA_twofactor_call(struct GA_twofactor_call* call);

/**
 * Return the next call in the chain
 * @call The parent call, already resolved and called via GA_twofactor_call
 * @next The returned next call in the chain
 *
 * Two factor authentication calls can be chained together such that multiple calls need to be
 * resolved and called to complete the operation. For example to enable sms as a 2fa method
 * requires calling twofactor.init_enable_sms and then twofactor.enable_sms, but both of those
 * underlying calls are implemented by the GA_twofactor_call returned by GA_twofactor_enable("sms").
 *
 * After calling GA_twofactor_call successfully the caller should call GA_twofactor_next_call to
 * determine if there is a further call to be resolved and called to complete the operation.
 */
GASDK_API int GA_twofactor_next_call(struct GA_twofactor_call* call, struct GA_twofactor_call** next);

/**
 * Free a GA_twofactor_call
 * @call Call to free
 *
 * GA_twofactor_call pointers returned by GA_twofactor_xxx functions need to be freed by
 * calling GA_destroy_twofactor_call. Note that calls returned by calling GA_twofactor_next_call
 * are automatically freed when the parent call is freed and so MUST NOT be passed to
 * GA_destroy_twofactor_call.
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

#ifdef __cplusplus
}
#endif

#endif
