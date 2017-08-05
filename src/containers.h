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

/** An view onto a GA transaction */
struct GA_tx_view;

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
int GA_tx_populate_view(struct GA_tx* tx, struct GA_tx_view** output);

/**
 *
 */
int GA_tx_view_get_received_on(struct GA_tx_view* view, const char** output, size_t count);
int GA_tx_view_get_counterparty(struct GA_tx_view* view, const char** output);
int GA_tx_view_get_hash(struct GA_tx_view* view, const char** output);
int GA_tx_view_get_double_spent_by(struct GA_tx_view* view, const char** output);
int GA_tx_view_get_value(struct GA_tx_view* view, int64_t* output);
int GA_tx_view_get_fee(struct GA_tx_view* view, int64_t* output);
int GA_tx_view_get_block_height(struct GA_tx_view* view, size_t* output);
int GA_tx_view_get_size(struct GA_tx_view* view, size_t* output);
int GA_tx_view_get_instant(struct GA_tx_view* view, int* output);
int GA_tx_view_get_replaceable(struct GA_tx_view* view, int* output);
int GA_tx_view_get_is_spent(struct GA_tx_view* view, int* output);
int GA_tx_view_get_type(struct GA_tx_view* view, int* output);

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
int GA_destroy_tx_view(const struct GA_tx_view* view);

#ifdef __cplusplus
}
#endif

#endif
