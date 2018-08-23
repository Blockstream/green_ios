#ifndef GA_SDK_SESSION_H
#define GA_SDK_SESSION_H
#pragma once

#include <sys/types.h>

#include "containers.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Network parameters to use */
#define GA_NETWORK_MAINNET 0
#define GA_NETWORK_TESTNET 1
#define GA_NETWORK_LOCALTEST 100
#define GA_NETWORK_REGTEST 101

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

/** Values for address types */
#define GA_ADDRESS_TYPE_P2SH 0
#define GA_ADDRESS_TYPE_P2WSH 1
#define GA_ADDRESS_TYPE_CSV 2
#define GA_ADDRESS_TYPE_DEFAULT 0xffffffff

/** Values for subaccount types */
#define GA_2OF2 0
#define GA_2OF3 1

/** Values for onion uri flag */
#define GA_NO_TOR 0
#define GA_USE_TOR 1

/** Value representing all subaccounts including the main account */
#define GA_ALL_ACCOUNTS 0xffffffff

/** Values for transaction memo type */
#define GA_MEMO_USER 0
#define GA_MEMO_BIP70 1

#/** An server session */
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
 *
 * @session Session to free.
 */
int GA_destroy_session(struct GA_session* session);

/**
 * Connect to a remote server using the specified network.
 *
 * @session The server session to use.
 * @network The network parameters to use.
 * @debug Output transport debug information to stderr.
 *
 * GA_ERROR if connection is unsuccessful.
 */
int GA_connect(struct GA_session* session, uint32_t network, uint32_t debug);

/**
 * Connect to a remote server using the specified network and proxy.
 *
 * @session The server session to use.
 * @network The network parameters to use.
 * @proxy The proxy server to use.
 * @use_tor Use the onion address for the @network.
 * @debug Output transport debug information to stderr.
 *
 * GA_ERROR if connection is unsuccessful.
 */
int GA_connect_with_proxy(
    struct GA_session* session, uint32_t network, const char* proxy_uri, uint32_t use_tor, uint32_t debug);

/**
 * UNUSED
 */
int GA_disconnect(struct GA_session* session);

/**
 * Create a new user account.
 *
 * @session The server session to use.
 * @mnemonic The user mnemonic.
 *
 * GA_ERROR if registration is unsuccessful.
 */
int GA_register_user(struct GA_session* session, const char* mnemonic);

/**
 * Authenticate an user.
 *
 * @session The server session to use.
 * @mnemonic The user mnemonic.
 *
 * GA_ERROR if authentication is unsuccessful.
 */
int GA_login(struct GA_session* session, const char* mnemonic, struct GA_login_data** login_data);

/**
 * Authenticate an user.
 *
 * @session The server session to use.
 * @pin The user pin.
 * @pin_identifier The pin identifier returned by @GA_set_pin.
 * @secret The secret returned by @GA_set_pin.
 *
 * GA_ERROR if authentication is unsuccessful.
 */
int GA_login_with_pin(struct GA_session* session, const char* pin, const char* pin_identifier, const char* secret,
    struct GA_login_data** login_data);

/**
 * Authenticate an user in watch only mode.
 *
 * @session The server session to use.
 * @username The username.
 * @password The password.
 *
 * GA_ERROR if authentication is unsuccessful.
 */
int GA_login_watch_only(
    struct GA_session* session, const char* username, const char* password, struct GA_login_data** login_data);

/**
 * Remove an account.
 *
 * @session The server session to use.
 *
 * GA_ERROR if removal is unsuccessful.
 */
int GA_remove_account(struct GA_session* session);

/**
 * Create a subaccount.
 *
 * @session The server session to use.
 * @type The subaccount type (one of @GA_2OF2 or @GA_2OF3).
 * @name The subaccount label.
 * @recovery_mnemonic The @GA_2OF3 subaccount recovery mnemonic.
 * @recovery_xpub The @GA_2OF3 subaccount recovery xpub.
 *
 * GA_ERROR if creation is unsuccessful.
 */
int GA_create_subaccount(
    struct GA_session* session, uint32_t type, const char* name, char** recovery_mnemonic, char** recovery_xpub);

/**
 * Change privacy (send me) settings.
 *
 * @session The server session to use.
 * @param One of @GA_PRIVATE, @GA_ADDRBOOK, @GA_PUBLIC
 *
 * GA_ERROR if settings could not be changed.
 */
int GA_change_settings_privacy_send_me(struct GA_session* session, uint32_t value);

/**
 * Change privacy (show as sender) settings.
 *
 * @session The server session to use.
 * @param One of @GA_PRIVATE, @GA_MUTUAL_ADDRBOOK, @GA_PUBLIC
 *
 * GA_ERROR if settings could not be changed.
 */
int GA_change_settings_privacy_show_as_sender(struct GA_session* session, uint32_t value);

/**
 * Change transaction limits settings.
 *
 * @session The server session to use.
 * @is_fiat One of @GA_TRUE or @GA_FALSE.
 * @per_tx Amount per transaction in satoshis.
 * @total Amount in total per transaction in satoshis.
 *
 * GA_ERROR if transaction limits could not be changed.
 */
int GA_change_settings_tx_limits(struct GA_session* session, uint32_t is_fiat, uint32_t per_tx, uint32_t total);

/**
 * Get list of user's transactions for a subaccount on the specified date range.
 *
 * @session The server session to use.
 * @subaccount The subaccount to which transactions belong to, or GA_ALL_ACCOUNTS.
 * @begin_date The begin date of the date range to search.
 * @end_date The end date of the date range to search.
 * @sort_by Return results ordered by timestamp or by value.
 * @page_id The page to fetch.
 * @query Extra query parameters.
 * @txs The list of transactions.
 *
 * GA_ERROR if transactions could not be fetched.
 */
int GA_get_tx_list(struct GA_session* session, uint32_t subaccount, time_t begin_date, time_t end_date,
    uint32_t sort_by, uint32_t page_id, const char* query, struct GA_tx_list** txs);

/**
 * @session The server session to use.
 * @subaccount The subaccount to generate an address for.
 * @addr_type The type of address P2SH or P2WSH.
 * @address The generated address.
 *
 * GA_ERROR if address could not be generated.
 */
int GA_get_receive_address(struct GA_session* session, uint32_t subaccount, uint32_t addr_type, char** address);

/**
 * The sum of unspent outputs destined to user’s wallet.
 *
 * @session The server session to use.
 * @subaccount The subaccount to get the balance for, or GA_ALL_ACCOUNTS.
 * @num_confs The number of required confirmations.
 * @balance The returned balance.
 *
 * GA_ERROR if balance could not be retrieved.
 */
int GA_get_balance(struct GA_session* session, uint32_t subaccount, uint32_t num_confs, struct GA_balance** balance);

/**
 * The list of allowed currencies for all available pricing sources.
 *
 * @session The server session to use.
 * @available_currencies The returned list of currencies.
 *
 * GA_ERROR if available_currencies could not be retrieved.
 */
int GA_get_available_currencies(struct GA_session* session, struct GA_available_currencies** available_currencies);

/**
 * Set a PIN for the user wallet.
 *
 * @session The server session to use.
 * @mnemonic The user mnemonic.
 * @pin The user pin.
 * @device The user device identifier.
 * @pin_identifier The returned identifier.
 * @secret The returned secret.
 *
 * GA_ERROR if pin could not be set.
 */
int GA_set_pin(struct GA_session* session, const char* mnemonic, const char* pin, const char* device,
    char** pin_identifier, char** secret);

/*
 * Send a transaction for the specified address/amount pairs.
 *
 * @session The server session to use.
 * @subaccount The subaccount to send from, or GA_ALL_ACCOUNTS.
 * @addr The addresses to send.
 * @add_siz The count of items in @addr.
 * @amt The amounts to send.
 * @amt_siz The count of items in @amt.
 * @fee_rate The fee rate.
 * @send_all One of @GA_TRUE or @GA_FALSE.
 *
 * GA_ERROR if raw transaction could not be created.
 */
int GA_send(struct GA_session* session, uint32_t subaccount, const char** addr, size_t add_siz, const uint64_t* amt,
    size_t amt_siz, uint64_t fee_rate, uint32_t send_all);

/**
 * Add a transaction memo to a users' GreenAddress transaction.
 *
 * @session The server session to use.
 * @txhash_hex The transaction hash to associate the memo with.
 * @memo The memo to set.
 * @memo_type The type of memo to set, either GA_MEMO_USER or GA_MEMO_BIP70.
 *
 * GA_ERROR if the memo is invalid, the transaction does not belong to the
 * user or the type is unknown.
 */
int GA_set_transaction_memo(struct GA_session* session, const char* txhash_hex, const char* memo, uint32_t memo_type);

/**
 * Set the pricing source for a users' GreenAddress wallet.
 *
 * @session The server session to use.
 * @currency The currency to use.
 * @exchange The exchange to use.
 *
 * GA_ERROR if the currency or exchange are invalid.
 */
int GA_set_pricing_source(struct GA_session* session, const char* currency, const char* exchange);

/*
 * Get a system message.
 *
 * @session The server session to use.
 * @message_id The id of the message to get. Returns the id of the next message or 0 if none.
 * @message_text UTF-8 encoded message text.
 *
 * GA_ERROR if the message does not exist or could not be retrieved.
 */
int GA_get_system_message(struct GA_session* session, uint32_t* message_id, const char** message_text);

/*
 * Sign and acknowledge a system message.
 *
 * The message text will be signed with a key derived from the wallet master key and the signature
 * sent to the server.
 *
 * @session The server session to use.
 * @message_id The id of the message.
 * @message_text UTF-8 encoded message text being acknowledged.
 *
 * GA_ERROR if the message or signature is invalid.
 */
int GA_ack_system_message(struct GA_session* session, uint32_t message_id, const char* message_text);

int GA_get_twofactor_config(struct GA_session* session, struct GA_twofactor_config** config);

#ifndef SWIG
/*
 * Subscribe to a notification topic.
 *
 * @session The server session to use.
 * @topic The topic to subscribe to.
 * @callback The callback for the topic value as JSON.
 *
 * GA_ERROR if topic cannot be subscribed to.
 */
int GA_subscribe_to_topic_as_json(
    struct GA_session* session, const char* topic, void (*callback)(void*, char* output), void* context);
#endif

#ifdef __cplusplus
}
#endif

#endif
