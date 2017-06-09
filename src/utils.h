#ifndef GA_SDK_UTILS_H
#define GA_SDK_UTILS_H
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Get up to 32 random bytes.
 *
 * Generates up to 32 random bytes using same strategy as Bitcoin Core code.
 * @bytes output buffer
 * @siz number of bytes to return (max. 32)
 *
 * GA_ERROR if it fails to generate the requested amount of random bytes.
 */
int GA_get_random_bytes(unsigned char* bytes, size_t siz);

#ifdef __cplusplus
}
#endif

#endif
