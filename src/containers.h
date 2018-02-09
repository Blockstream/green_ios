#ifndef GA_SDK_CONTAINERS_H
#define GA_SDK_CONTAINERS_H
#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** An dict of string/value pairs */
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

/** An GA transaction list */
struct GA_tx_list;

/** An GA transaction */
struct GA_tx;

/** An balance representation */
struct GA_balance;

/** An available currencies representation */
struct GA_available_currencies;

/** An login data representation */
struct GA_login_data;

/**
 *
 */
int GA_convert_tx_list_path_to_dict(struct GA_tx_list* txs, const char* path, struct GA_dict** value);

/**
 *
 */
int GA_convert_tx_list_path_to_string(struct GA_tx_list* txs, const char* path, char** value);

/**
 *
 */
int GA_convert_tx_list_to_json(struct GA_tx_list* txs, char** output);

/**
 *
 */
int GA_tx_list_get_size(struct GA_tx_list* txs, size_t* output);

/**
 *
 */
int GA_tx_list_get_tx(struct GA_tx_list* txs, size_t i, struct GA_tx** output);

/**
 *
 */
int GA_transaction_to_json(struct GA_tx* balance, char** output);

/**
 *
 */
int GA_convert_balance_to_json(struct GA_balance* balance, char** output);

/**
 *
 */
int GA_convert_login_data_to_json(struct GA_login_data* login_data, char** output);

/**
 *
 */
int GA_convert_available_currencies_to_json(struct GA_available_currencies* available_currencies, char** output);

/**
 *
 */
void GA_destroy_dict(struct GA_dict* dict);

/**
 *
 */
void GA_destroy_string(const char* str);

/**
 * Free a GA_tx_list allocated by @GA_get_tx_list
 * @txs GA_tx_list to free.
 */
int GA_destroy_tx_list(struct GA_tx_list* txs);

/**
 *
 */
int GA_destroy_tx(const struct GA_tx* tx);

/**
 *
 */
int GA_destroy_balance(const struct GA_balance* balance);

/**
 *
 */
int GA_destroy_available_currencies(const struct GA_available_currencies* o);

/**
 *
 */
int GA_destroy_login_data(const struct GA_login_data* login_data);

#ifdef __cplusplus
}
#endif

#endif
