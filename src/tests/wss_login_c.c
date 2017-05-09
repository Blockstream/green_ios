#include "session.h"

const char* DEFAULT_ENDPOINT = "ws://localhost:8080/v2/ws";
const char* DEFAULT_MNEMONIC
    = "believe roast zen poorer tax chicken snap calm override french banner salmon bird sad smart ";
const char* DEFAULT_USER_AGENT = "[sw]";

int main(int argc, char* argv[])
{
    int ret = GA_OK;

    struct GA_session* session = GA_create_session();

    ret = GA_connect(session, DEFAULT_ENDPOINT, 0);
    ret = GA_register_user(session, DEFAULT_MNEMONIC, DEFAULT_USER_AGENT);
    ret = GA_login(session, DEFAULT_MNEMONIC, DEFAULT_USER_AGENT);

    GA_destroy_session(session);

    return ret;
}
