from greenaddress import Session, generate_mnemonic
import random
import string

random_email = lambda: '@@' + ''.join(random.choice(string.ascii_letters) for i in range(16))

def do_2fa(session, method, confirmed, enabled):
    data = '+123456789'
    if method == 'gauth':
        data = session.get_twofactor_config()['gauth']['data']
    if method == 'email':
        data = random_email()

    cfg = { 'confirmed': confirmed, 'enabled': enabled, 'data': data }
    session.change_settings_twofactor(method, cfg).resolve()
    return session


def do_test(network, debug):

    all_methods = [ 'email', 'gauth', 'phone', 'sms']
    sessions = {}

    # Enable all 2fa methods as the initial method for a new session
    for method in all_methods:
        words = generate_mnemonic()
        session = Session(network, '', False, debug).register_user(words).login(words)
        sessions[method] = do_2fa(session, method, True, True)

    # Enable the remainder of the methods for each
    for enabled_method, session in sessions.items():
        for method in [m for m in all_methods if m != enabled_method]:
            do_2fa(session, method, True, True)

    # Disable all methods for each session
    for enabled_method, session in sessions.items():
        #for method in all_methods: # FIXME: We get rate limited if we disable them all
        for method in [enabled_method]:
            # FIXME: Setting confirmed: True to just disable currently fails
            do_2fa(session, method, False, False)

    # Enable email on a new session, request and then cancel a 2fa reset
    words = generate_mnemonic()
    session = Session(network, '', False, debug).register_user(words).login(words)
    do_2fa(session, 'email', True, True)
    session.twofactor_reset(random_email(), False).resolve()
    session.twofactor_cancel_reset().resolve()


if __name__ == "__main__":
    do_test('localtest', False)
