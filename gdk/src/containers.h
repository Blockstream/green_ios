#ifndef GA_SDK_CONTAINERS_H
#define GA_SDK_CONTAINERS_H
#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** A dict of string/value pairs */
struct GA_dict;

/**
 *
 */
// int GA_convert_dict_value_to_string(struct GA_dict* dict, const char* path, char** value);

/**
 *
 */
// int GA_convert_dict_value_to_unsigned_integer(struct GA_dict* dict, const char* path, size_t* value);

/**
 *
 */
// int GA_convert_dict_value_to_bool(struct GA_dict* dict, const char* path, int* value);

/** A GA transaction list */
struct GA_tx_list;

/** A GA transaction */
struct GA_tx;

/** A balance representation */
struct GA_balance;

/** An available currencies representation */
struct GA_available_currencies;

/** A login data representation */
struct GA_login_data;

/** A utxo representation */
struct GA_utxo;

/** Two factor authentication configuration data **/
struct GA_twofactor_config;

/** Two factor authentication data **/
struct GA_twofactor_data;

/**
 *
 */
int GA_convert_tx_list_path_to_dict(struct GA_tx_list* obj, const char* path, struct GA_dict** value);

/**
 *
 */
int GA_convert_tx_list_path_to_string(struct GA_tx_list* obj, const char* path, char** value);

/**
 * Get size of transaction list.
 * @txs The transaction list.
 * @output The returned size of the transaction list.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_tx_list_get_size(struct GA_tx_list* txs, size_t* output);

/**
 * Get the i'th transaction in the list
 * @txs The transaction list.
 * @output The returned transaction or NULL if not found.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_tx_list_get_tx(struct GA_tx_list* txs, size_t i, struct GA_tx** output);

/**
 * Convert transaction list to JSON.
 * @txs The transaction list to convert.
 * @output The returned JSON representation.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_convert_tx_list_to_json(struct GA_tx_list* txs, char** output);

/**
 * Convert transaction to JSON.
 * @tx The transaction to convert.
 * @output The returned JSON representation.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_transaction_to_json(struct GA_tx* tx, char** output);

/**
 * Convert balance to JSON.
 * @balance The balance to convert.
 * @output The returned JSON representation.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_convert_balance_to_json(struct GA_balance* balance, char** output);

/**
 * Convert login data to JSON.
 * @login_data The login data to convert.
 * @output The returned JSON representation.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_convert_login_data_to_json(struct GA_login_data* login_data, char** output);

/**
 * Convert two factor config to JSON
 * @twofactor_config The two factor config data to convert.
 * @output The returned JSON representation.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_convert_twofactor_config_to_json(struct GA_twofactor_config* twofactor_config, char** output);

/**
 * Convert JSON to two factor data.
 * @input The JSON representation of the two factor data
 * @twofactor_data The returned two factor data.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_convert_twofactor_data_from_json(const char* input, struct GA_twofactor_data** twofactor_data);

/**
 * Convert available currencies to JSON.
 * @currencies The currencies to convert.
 * @output The returned JSON representation.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_convert_available_currencies_to_json(struct GA_available_currencies* currencies, char** output);

/**
 * Free a GA_dict.
 * @dict GA_dict to free.
 *
 * GA_ERROR if unsuccessful.
 */
void GA_destroy_dict(struct GA_dict* dict);

/**
 * Free a GA_tx_list allocated by @GA_get_tx_list.
 * @txs GA_tx_list to free.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_destroy_tx_list(struct GA_tx_list* txs);

/**
 * Free a GA_tx.
 * @tx GA_tx to free.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_destroy_tx(const struct GA_tx* tx);

/**
 * Free a GA_balance.
 * @balance GA_balance to free.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_destroy_balance(const struct GA_balance* balance);

/**
 * Free a GA_available_currencies.
 * @currencies GA_available_currencies to free.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_destroy_available_currencies(const struct GA_available_currencies* currencies);

/**
 * Free a GA_login_data.
 * @login_data GA_login_data to free.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_destroy_login_data(const struct GA_login_data* login_data);

/**
 * Free a GA_twofactor_config.
 * @twofactor_config GA_twofactor_config to free.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_destroy_twofactor_config(const struct GA_twofactor_config* twofactor_config);

/**
 * Free a GA_twofactor_data.
 * @twofactor_data GA_twofactor_data to free.
 *
 * GA_ERROR if unsuccessful.
 */
int GA_destroy_twofactor_data(const struct GA_twofactor_data* twofactor_data);

#ifdef __cplusplus
}
#endif

#endif
