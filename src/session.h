#ifndef GA_SDK_SESSION_H
#define GA_SDK_SESSION_H
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/** Error codes for API calls */
#define GA_OK 0
#define GA_ERROR -1

/** Network parameters to use */
#define GA_NETWORK_LOCALTEST 0
#define GA_NETWORK_REGTEST 1
#define GA_NETWORK_TESTNET 2

/** Boolean values */
#define GA_TRUE 1
#define GA_FALSE 0

/** Values for privacy settings */
#define GA_PRIVATE 0
#define GA_ADDRBOOK 1
#define GA_MUTUAL_ADDRBOOK 1
#define GA_PUBLIC 2

/** An server session */
struct GA_session;

/**
 * Create a new server session.
 *
 * This creates a new server session, i.e. initialises internal data structures to allow RPC calls.
 * @session Destination for the resulting session.
 *
 * GA_ERROR if memory allocation fails.
 */
int GA_create_session(struct GA_session** session);

/**
 * Free a session allocated by @GA_create_session
 * @session Session to free.
 */
void GA_destroy_session(struct GA_session* session);

/**
 * Connect to a remote server using the specified network.
 * @session The server session to use.
 * @network The network parameters to use.
 * @debug Output transport debug information to stderr.
 *
 * GA_ERROR if connection is unsuccessful.
 */
int GA_connect(struct GA_session* session, int network, int debug);

/**
 * UNUSED
 */
int GA_disconnect(struct GA_session* session);

/**
 * Create a new user account.
 * @session The server session to use.
 * @mnemonic The user mnemonic.
 * @user_agent Optional string to identify this client.
 *
 * GA_ERROR if registration is unsuccessful.
 */
int GA_register_user(struct GA_session* session, const char* mnemonic, const char* user_agent);

/**
 * Authenticate an user.
 * @session The server session to use.
 * @mnemonic The user mnemonic.
 * @user_agent Optional string to identify this client.
 *
 * GA_ERROR if authentication is unsuccessful.
 */
int GA_login(struct GA_session* session, const char* mnemonic, const char* user_agent);

/**
 * Change privacy (send me) settings.
 * @session The server session to use.
 * @param One of @GA_PRIVATE, @GA_ADDRBOOK, @GA_PUBLIC
 *
 * GA_ERROR if settings could not be changed.
 */
int GA_change_settings_privacy_send_me(struct GA_session* session, int param);

/**
 * Change privacy (show as sender) settings.
 * @session The server session to use.
 * @param One of @GA_PRIVATE, @GA_MUTUAL_ADDRBOOK, @GA_PUBLIC
 *
 * GA_ERROR if settings could not be changed.
 */
int GA_change_settings_privacy_show_as_sender(struct GA_session* session, int param);

/**
 * Change transaction limits settings.
 * @is_fiat One of @GA_TRUE or @GA_FALSE.
 * @per_tx Amount per transaction in satoshis.
 * @total Amount in total per transaction in satoshis.
 *
 * GA_ERROR if transaction limits could not be changed.
 */
int GA_change_settings_tx_limits(struct GA_session* session, int is_fiat, int per_tx, int total);

#ifdef __cplusplus
}
#endif

#endif
