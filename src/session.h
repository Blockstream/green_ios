#ifndef GA_SDK_SESSION_H
#define GA_SDK_SESSION_H
#pragma once

#include <time.h>

#include "containers.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Network parameters to use */
#define GA_NETWORK_LOCALTEST 0
#define GA_NETWORK_REGTEST 1
#define GA_NETWORK_TESTNET 2

/** Values for privacy settings */
#define GA_PRIVATE 0
#define GA_ADDRBOOK 1
#define GA_MUTUAL_ADDRBOOK 1
#define GA_PUBLIC 2

/** Values for transactions list */
#define GA_TIMESTAMP 0
#define GA_TIMESTAMP_ASCENDING 1
#define GA_TIMESTAMP_DESCENDING 2
#define GA_VALUE 3
#define GA_VALUE_ASCENDING 4
#define GA_VALUE_DESCENDING 5

/** Value for address types */
#define GA_ADDRESS_TYPE_P2SH 0
#define GA_ADDRESS_TYPE_P2WSH 1

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
int GA_destroy_session(struct GA_session* session);

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
 *
 * GA_ERROR if registration is unsuccessful.
 */
int GA_register_user(struct GA_session* session, const char* mnemonic);

/**
 * Authenticate an user.
 * @session The server session to use.
 * @mnemonic The user mnemonic.
 *
 * GA_ERROR if authentication is unsuccessful.
 */
int GA_login(struct GA_session* session, const char* mnemonic);

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
 * @session The server session to use.
 * @is_fiat One of @GA_TRUE or @GA_FALSE.
 * @per_tx Amount per transaction in satoshis.
 * @total Amount in total per transaction in satoshis.
 *
 * GA_ERROR if transaction limits could not be changed.
 */
int GA_change_settings_tx_limits(struct GA_session* session, int is_fiat, int per_tx, int total);

/**
 * Get list of user's transactions for a subaccount on the specified date range.
 * @session The server session to use.
 * @begin_date The begin date of the date range to search.
 * @end_date The end date of the date range to search.
 * @subaccount The subaccount to which transactions belong to.
 * @sort_by Return results ordered by timestamp or by value.
 * @page_id The page to fetch.
 * @query Extra query parameters.
 * @txs The list of transactions.
 *
 * GA_ERROR if transactions could not be fetched.
 */
int GA_get_tx_list(struct GA_session* session, time_t begin_date, time_t end_date, size_t subaccount, int sort_by,
    size_t page_id, const char* query, struct GA_tx_list** txs);

/**
 * @session The server session to use.
 * @addr_type The type of address P2SH or P2WSH.
 * @subaccount The subaccount to which transactions belong to.
 * @address The generated address.
 *
 * GA_ERROR if address could not be generated.
 */
int GA_get_receive_address(struct GA_session* session, int addr_type, size_t subaccount, char** address);

/**
 * The sum of unspent outputs destined to user’s wallet.
 * @session The server session to use.
 * @subaccount The subaccount pointer.
 * @num_confs The number of required confirmations.
 * @balance The returned balance.
 *
 * GA_ERROR if balance could not be retrieved.
 */
int GA_get_balance_for_subaccount(
    struct GA_session* session, size_t subaccount, size_t num_confs, struct GA_balance** balance);

/**
 * The sum of unspent outputs destined to user’s wallet.
 * @session The server session to use.
 * @num_confs The number of required confirmations.
 * @balance The returned balance.
 *
 * GA_ERROR if balance could not be retrieved.
 */
int GA_get_balance(struct GA_session* session, size_t num_confs, struct GA_balance** balance);

#ifdef __cplusplus
}
#endif

#endif
