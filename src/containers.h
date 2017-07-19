#ifndef GA_SDK_CONTAINERS_H
#define GA_SDK_CONTAINERS_H
#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/** An dict of string/value pairs */
struct GA_dict;

/**
 *
 */
int GA_convert_dict_value_to_string(struct GA_dict* dict, const char* path, char** value);

/**
 *
 */
int GA_convert_dict_value_to_unsigned_integer(struct GA_dict* dict, const char* path, size_t* value);

/**
 *
 */
int GA_convert_dict_value_to_bool(struct GA_dict* dict, const char* path, int* value);

/** An transaction list */
struct GA_tx_list;

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
int GA_convert_tx_list_to_json(struct GA_tx_list* txs, char** json);

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

#ifdef __cplusplus
}
#endif

#endif
