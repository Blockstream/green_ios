#ifndef GA_SDK_SESSION_H
#define GA_SDK_SESSION_H
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define GA_OK 0
#define GA_ERROR -1

#define GA_NETWORK_REGTEST 0

struct GA_session;

int GA_create_session(struct GA_session** session);

void GA_destroy_session(struct GA_session*);

int GA_connect(struct GA_session* session, int network, int debug);

int GA_disconnect(struct GA_session* session);

int GA_register_user(struct GA_session* session, const char* mnemonic, const char* user_agent);

int GA_login(struct GA_session* session, const char* mnemonic, const char* user_agent);

#ifdef __cplusplus
}
#endif

#endif
