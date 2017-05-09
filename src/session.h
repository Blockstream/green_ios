#ifndef GA_SDK_SESSION_H
#define GA_SDK_SESSION_H
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct GA_session;

struct GA_session* GA_create_session();

void GA_destroy_session(struct GA_session*);

#ifdef __cplusplus
}
#endif

#endif
