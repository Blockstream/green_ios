#include "session.h"

int main(int argc, char* argv[])
{
    struct GA_session* session = GA_create_session();
    GA_destroy_session(session);
    return 0;
}
