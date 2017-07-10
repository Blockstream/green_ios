#ifndef GA_SDK_UTILS_H
#define GA_SDK_UTILS_H
#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Get up to 32 random bytes.
 *
 * Generates up to 32 random bytes using the same strategy as Bitcoin Core code.
 * @bytes output buffer
 * @siz number of bytes to return (max. 32)
 *
 * GA_ERROR if it fails to generate the requested amount of random bytes.
 */
int GA_get_random_bytes(unsigned char* bytes, size_t siz);

/**
 * Generate mnemonic.
 *
 * Generates a BIP39 mnemonic.
 * @lang language for the default word list
 * @mnemonic the generated mnemonic phrase
 *
 * GA_ERROR if mnemonic generation fails
 */
int GA_generate_mnemonic(const char* lang, char** mnemonic);

#ifdef __cplusplus
}
#endif

#endif
