#ifndef GA_SDK_UTILS_H
#define GA_SDK_UTILS_H
#pragma once

#include "containers.h"
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef SWIG
/**
 * Copy a string.
 * @src The string to copy.
 * @dst The new string.
 *
 * GA_ERROR if unsuccessful.
 */
GASDK_API void GA_copy_string(const char* src, char** dst);

/**
 * Free a string.
 * @str The string to free.
 *
 * GA_ERROR if unsuccessful.
 */
GASDK_API void GA_destroy_string(const char* str);
#endif

/**
 * Get up to 32 random bytes.
 *
 * Generates up to 32 random bytes using the same strategy as Bitcoin Core code.
 * @output_bytes bytes output buffer
 * @siz number of bytes to return (max. 32)
 *
 * GA_ERROR if it fails to generate the requested amount of random bytes.
 */
GASDK_API int GA_get_random_bytes(size_t num_bytes, unsigned char* output_bytes, size_t len);

/**
 * Generate mnemonic.
 *
 * Generates a BIP39 mnemonic.
 * @output the generated mnemonic phrase
 *
 * GA_ERROR if mnemonic generation fails
 */
GASDK_API int GA_generate_mnemonic(char** output);

/**
 * Validate mnemonic.
 *
 * Validates a BIP39 mnemonic.
 * @mnemonic the mnemonic phrase
 *
 * GA_FALSE if mnemonic validation fails
 */
GASDK_API int GA_validate_mnemonic(const char* mnemonic);

#ifndef SWIG
/**
 * Parse Bitcoin URI.
 *
 * @uri The URI to parse
 * @output The JSON representation of a dictionary containing the elements
 *
 * GA_FALSE if parsing fails
 */
GASDK_API int GA_parse_bitcoin_uri(const char* uri, GA_json** output);
#endif

#ifdef __cplusplus
}
#endif

#endif
