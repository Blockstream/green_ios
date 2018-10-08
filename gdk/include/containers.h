#ifndef GA_SDK_CONTAINERS_H
#define GA_SDK_CONTAINERS_H
#pragma once

#include <stddef.h>
#include <stdint.h>

#include "common.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef SWIG

GASDK_API int GA_convert_json_to_string(const GA_json* json, char** output);

GASDK_API int GA_convert_string_to_json(const char* input, GA_json** output);

GASDK_API int GA_convert_json_value_to_string(const GA_json* json, const char* path, char** output);

GASDK_API int GA_convert_json_value_to_uint32(const GA_json* json, const char* path, uint32_t* output);

GASDK_API int GA_convert_json_value_to_uint64(const GA_json* json, const char* path, uint64_t* output);

GASDK_API int GA_convert_json_value_to_bool(const GA_json* json, const char* path, uint32_t* output);

/**
 * Free a GA_json object.
 * @json GA_json object to free.
 *
 * GA_ERROR if unsuccessful.
 */
GASDK_API int GA_destroy_json(GA_json* json);

#endif // SWIG

#ifdef __cplusplus
}
#endif

#endif
