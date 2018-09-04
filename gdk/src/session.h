#ifndef GA_SDK_SESSION_H
#define GA_SDK_SESSION_H
#pragma once

#include <sys/types.h>

#include "common.h"
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

/** Values for address types */
#define GA_ADDRESS_TYPE_P2SH 0
#define GA_ADDRESS_TYPE_P2WSH 1
#define GA_ADDRESS_TYPE_CSV 2
#define GA_ADDRESS_TYPE_DEFAULT 0xffffffff

/** Values for onion uri flag */
#define GA_NO_TOR 0
#define GA_USE_TOR 1

/** Value representing all subaccounts including the main account */
#define GA_ALL_ACCOUNTS 0xffffffff

/** Values for transaction memo type */
#define GA_MEMO_USER 0
#define GA_MEMO_BIP70 1

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
GASDK_API int GA_create_session(struct GA_session** session);

/**
 * Free a session allocated by @GA_create_session
 *
 * @session Session to free.
 */
GASDK_API int GA_destroy_session(struct GA_session* session);

/**
 * Connect to a remote server using the specified network.
 *
 * @session The server session to use.
 * @network The network parameters to use.
 * @debug Output transport debug information to stderr.
 *
 * GA_ERROR if connection is unsuccessful.
 */
GASDK_API int GA_connect(struct GA_session* session, uint32_t network, uint32_t debug);

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
GASDK_API int GA_connect_with_proxy(
    struct GA_session* session, uint32_t network, const char* proxy_uri, uint32_t use_tor, uint32_t debug);

/**
 * UNUSED
 */
GASDK_API int GA_disconnect(struct GA_session* session);

/**
 * Create a new user account.
 *
 * @session The server session to use.
 * @mnemonic The user mnemonic.
 *
 * GA_ERROR if registration is unsuccessful.
 */
GASDK_API int GA_register_user(struct GA_session* session, const char* mnemonic);

/**
 * Authenticate an user.
 *
 * @session The server session to use.
 * @mnemonic The user mnemonic.
 *
 * GA_ERROR if authentication is unsuccessful.
 */
GASDK_API int GA_login(struct GA_session* session, const char* mnemonic);

/**
 * Authenticate an user.
 *
 * @session The server session to use.
 * @pin The user pin.
 * @pin_data The encrypted pin data returned by @GA_set_pin.
 *
 * GA_ERROR if authentication is unsuccessful.
 */
GASDK_API int GA_login_with_pin(struct GA_session* session, const char* pin, const GA_json* pin_data);

/**
 * Authenticate an user in watch only mode.
 *
 * @session The server session to use.
 * @username The username.
 * @password The password.
 *
 * GA_ERROR if authentication is unsuccessful.
 */
GASDK_API int GA_login_watch_only(struct GA_session* session, const char* username, const char* password);

/**
 * Remove an account.
 *
 * @session The server session to use.
 *
 * GA_ERROR if removal is unsuccessful.
 */
GASDK_API int GA_remove_account(struct GA_session* session, const GA_json* twofactor_data);

/**
 * Create a subaccount.
 *
 * @session The server session to use.
 * @details The subaccount details. "name" (which must not be already used in
 *     the wallet) and "type" (either "2of2" or "2of3") must be populated. For
 *     type "2of3" the caller may provide "recovery_mnemonic" if they do not
 *     wish to have one generated automatically. All other fields are ignored.
 * @subaccount Destination for the created subaccount details. For 2of3
 *     subaccounts the extra fields "recovery_mnemonic" and "recovery_xpub"
 *     are populated. These values should be stored safely as they will not
 *     be returned again by any GDK call such as GA_get_subaccounts.
 *
 * GA_ERROR if creation is unsuccessful.
 */
GASDK_API int GA_create_subaccount(struct GA_session* session, const GA_json* details, GA_json** subaccount);

/**
 * Get the user's subaccount details.
 *
 * @session The server session to use.
 * @subaccounts Destination for the user's subaccounts.
 *
 * GA_ERROR if subaccounts could not be fetched.
 */
GASDK_API int GA_get_subaccounts(struct GA_session* session, GA_json** subaccounts);

/**
 * Change privacy (send me) settings.
 *
 * @session The server session to use.
 * @param One of @GA_PRIVATE, @GA_ADDRBOOK, @GA_PUBLIC
 *
 * GA_ERROR if settings could not be changed.
 */
GASDK_API int GA_change_settings_privacy_send_me(struct GA_session* session, uint32_t value);

/**
 * Change privacy (show as sender) settings.
 *
 * @session The server session to use.
 * @param One of @GA_PRIVATE, @GA_MUTUAL_ADDRBOOK, @GA_PUBLIC
 *
 * GA_ERROR if settings could not be changed.
 */
GASDK_API int GA_change_settings_privacy_show_as_sender(struct GA_session* session, uint32_t value);

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
GASDK_API int GA_change_settings_tx_limits(
    struct GA_session* session, uint32_t is_fiat, uint32_t per_tx, uint32_t total, const GA_json* twofactor_data);

/**
 * Set the pricing source for a user's GreenAddress wallet.
 *
 * @session The server session to use.
 * @currency The currency to use.
 * @exchange The exchange to use.
 *
 * GA_ERROR if the currency or exchange are invalid.
 */
GASDK_API int GA_change_settings_pricing_source(struct GA_session* session, const char* currency, const char* exchange);

/**
 * Get a page of the user's transaction history.
 *
 * @session The server session to use.
 * @subaccount The subaccount to fetch transactions for.
 * @page_id The page to fetch, starting from 0.
 * @txs The list of transactions.
 *
 * Transactions are returned from newest to oldest with up to 30 transactions per page.
 * GA_ERROR if transactions could not be fetched.
 */
GASDK_API int GA_get_transactions(struct GA_session* session, uint32_t subaccount, uint32_t page_id, GA_json** txs);

/**
 * An address to receive coins to.
 *
 * @session The server session to use.
 * @subaccount The subaccount to generate an address for.
 * @addr_type The type of address: P2SH, P2WSH, CSV or DEFAULT.
 * @output The generated address.
 *
 * GA_ERROR if address could not be generated.
 */
GASDK_API int GA_get_receive_address(
    struct GA_session* session, uint32_t subaccount, uint32_t addr_type, char** output);

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
GASDK_API int GA_get_balance(struct GA_session* session, uint32_t subaccount, uint32_t num_confs, GA_json** balance);

/**
 * The list of allowed currencies for all available pricing sources.
 *
 * @session The server session to use.
 * @available_currencies The returned list of currencies.
 *
 * GA_ERROR if available currencies could not be retrieved.
 */
GASDK_API int GA_get_available_currencies(struct GA_session* session, GA_json** available_currencies);

/**
 * Set a PIN for the user wallet.
 *
 * @session The server session to use.
 * @mnemonic The user mnemonic.
 * @pin The user pin.
 * @device The user device identifier.
 * @pin_data The returned encrypted PIN data.
 *
 * GA_ERROR if pin could not be set.
 */
GASDK_API int GA_set_pin(
    struct GA_session* session, const char* mnemonic, const char* pin, const char* device, GA_json** pin_data);

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
GASDK_API int GA_send(struct GA_session* session, uint32_t subaccount, const char** addr, size_t add_siz,
    const uint64_t* amt, size_t amt_siz, uint64_t fee_rate, uint32_t send_all, const GA_json* twofactor_data);

/**
 * Add a transaction memo to a user's GreenAddress transaction.
 *
 * @session The server session to use.
 * @txhash_hex The transaction hash to associate the memo with.
 * @memo The memo to set.
 * @memo_type The type of memo to set, either GA_MEMO_USER or GA_MEMO_BIP70.
 *
 * GA_ERROR if the memo is invalid, the transaction does not belong to the
 * user or the type is unknown.
 */
GASDK_API int GA_set_transaction_memo(
    struct GA_session* session, const char* txhash_hex, const char* memo, uint32_t memo_type);

/*
 * Get the latest un-acknowledged system message.
 *
 * @session The server session to use.
 * @message_text The returned UTF-8 encoded message text.
 *
 * GA_ERROR if the message could not be retrieved. If all current messages
 * are acknowledged, an empty string is returned.
 */
GASDK_API int GA_get_system_message(struct GA_session* session, const char** message_text);

/*
 * Sign and acknowledge a system message.
 *
 * The message text will be signed with a key derived from the wallet master key and the signature
 * sent to the server.
 *
 * @session The server session to use.
 * @message_text UTF-8 encoded message text being acknowledged.
 *
 * GA_ERROR if the message is not the latest message from GA_get_system_message.
 */
GASDK_API int GA_ack_system_message(struct GA_session* session, const char* message_text);

GASDK_API int GA_get_twofactor_config(struct GA_session* session, GA_json** config);

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
GASDK_API int GA_subscribe_to_topic_as_json(
    struct GA_session* session, const char* topic, void (*callback)(void*, char* output), void* context);
#endif

#ifdef __cplusplus
}
#endif

#endif
