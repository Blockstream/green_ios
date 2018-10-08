#ifndef GA_SDK_COMMON_H
#define GA_SDK_COMMON_H
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#ifndef GASDK_API
#if defined(_WIN32)
#ifdef GASDK_BUILD
#define GASDK_API __declspec(dllexport)
#else
#define GASDK_API
#endif
#elif defined(__GNUC__) && defined(GASDK_BUILD)
#define GASDK_API __attribute__((visibility("default")))
#else
#define GASDK_API
#endif
#endif

/** Error codes for API calls */
#define GA_OK 0
#define GA_ERROR (-1)
#define GA_RECONNECT (-2)
#define GA_SESSION_LOST (-3)
#define GA_TIMEOUT (-4)

/** Boolean values */
#define GA_TRUE 1
#define GA_FALSE 0

/** A server session */
struct GA_session;

/** A Parsed JSON object */
typedef struct GA_json GA_json;

/** An api method call that potentially requires two factor authentication to complete */
struct GA_twofactor_call;

/** A notification handler */
typedef void (*GA_notification_handler)(void* context, const GA_json* details);

#ifdef __cplusplus
}
#endif

#endif
