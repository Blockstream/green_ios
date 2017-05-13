#include <stdlib.h>

#include "session.h"

const char* DEFAULT_MNEMONIC
    = "believe roast zen poorer tax chicken snap calm override french banner salmon bird sad smart ";
const char* DEFAULT_USER_AGENT = "[sw]";

int main(int argc, char* argv[])
{
    int ret = GA_OK;

    struct GA_session* session = NULL;
    ret = GA_create_session(&session);

    ret = GA_connect(session, GA_NETWORK_LOCALTEST, 0);
    ret = GA_register_user(session, DEFAULT_MNEMONIC, DEFAULT_USER_AGENT);
    ret = GA_login(session, DEFAULT_MNEMONIC, DEFAULT_USER_AGENT);

    GA_destroy_session(session);

    return ret;
}
