from greenaddress import Session, generate_mnemonic
import random
import string


def get_data(session, method):
    if method == 'gauth':
        return session.get_twofactor_config()['gauth']['data']
    if method == 'email':
        lc = string.ascii_lowercase
        return '@@' + ''.join(random.choice(lc) for i in range(16))
    return '+123456789'


def do_test(network, debug):

    # Enable all 2fa methods as the initial method for a new session
    sessions = {}
    for method in [ 'email', 'gauth', 'phone', 'sms']:
        words = generate_mnemonic()
        session = Session(network, '', False, debug).register_user(words).login(words)
        cfg = { 'confirmed': True, 'enabled': True, 'data': get_data(session, method) }
        session.change_settings_twofactor(method, cfg).resolve()
        sessions[method] = session

    # Enable email on the gauth session
    session = sessions['gauth']
    method = 'email'
    cfg = { 'confirmed': True, 'enabled': True, 'data': get_data(session, method) }
    session.change_settings_twofactor(method, cfg).resolve()

    # Enable sms on the email session
    session = sessions['email']
    method = 'sms'
    cfg = { 'confirmed': True, 'enabled': True, 'data': get_data(session, method) }
    session.change_settings_twofactor(method, cfg).resolve()

    # Enable gauth on the phone session
    session = sessions['phone']
    method = 'gauth'
    cfg = { 'confirmed': True, 'enabled': True, 'data': get_data(session, method) }
    session.change_settings_twofactor(method, cfg).resolve()


if __name__ == "__main__":
    do_test('localtest', False)
