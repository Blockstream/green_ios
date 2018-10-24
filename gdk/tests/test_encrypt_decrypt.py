from greenaddress import Session
import json
import binascii


def test_greenbits_testvector(session):
    """Test that our encryption/decryption matches GreenBits"""
    MNEMONIC = 'once orbit focus sleep hire leave genre smart doctor mechanic across slim false ' \
               'olympic grape wisdom coffee hold point social theme private valid drift'
    CIPHERTEXT = 'adbf2fcd2f78e93a6508bc55051b4b4172f0c83b71dc51163d733c4d1c0e301dd21a000dd5128f1ab506dfbb241e8e076331b074b38e0d14a007701f0b1241b73fb39cec789900d8286ccf939af2b474c5bcca4f91fcf04eb3387eaafbf665fd5ea37b5874138115c42f0b8d24e79915b5f995fea2f2427eac61acc12559020851706907dc8bf058e9726cacf3b9c4d3ee2fae43f5532dcc90d459eebbdb420babd82d5d2d0aa0815c35ace3ef76a6ddf9597f1b53f8c43c13ef191b1e7ed2c4de3bf135044a05af761d32abc9bd1788aeb3eebe294640de5aafd312a4d4cc52a16703bb7a2406a405483184e027fab71d2c40ad2abb3cc9af437170443705ae'
    SALT = '4b9d66ea55b9fe9bda83e903050b2fad'

    session.register_user(MNEMONIC).login(MNEMONIC, '')
    plaintext = session.decrypt({'ciphertext': CIPHERTEXT, 'salt': SALT})['plaintext']
    plaintext = json.loads(plaintext)
    PLAINTEXT = {
        "subaccount": 0,
        "script": "5221029b5435f3cc4eb2d3eaa499108e8fafa34dd27b3d496dd2b5e072f35d6591bb0e2103776059a7a14c90bdf92b063772d09ca53a8ba734b8055335d88a2758105fa3d552ae",
        "subtype": None,
        "branch": 1,
        "pointer": 735,
        "addr_type": "p2wsh"
    }
    assert plaintext == PLAINTEXT

def test_roundtrips(session):
    """Test that encrypting/decrypting various plaintext roundtrips"""
    MNEMONIC = 'front strategy cry chronic base table divide zero ' \
               'spoon honey treat fatal cycle list soda iron copper ' \
               'mixed dizzy october math size country check'
    session.register_user(MNEMONIC).login(MNEMONIC, '')

    AES_BLOCK_LEN = 16
    last_generated_salt = None
    for plaintext in [
        '',
        'x',
        'x'*(AES_BLOCK_LEN-1),
        'x'*(AES_BLOCK_LEN),
        'x'*(AES_BLOCK_LEN+1),
        'x'*(AES_BLOCK_LEN*2),
        'x'*(AES_BLOCK_LEN*16),
        'x'*((AES_BLOCK_LEN*16)+1),
        "Hi Alice! Bob here",
        "abc"*128,
        ]:

        for password in [None, "0001090a0fff"]:
            for salt in [None, "01" * 16]:

                def with_password_and_salt(payload):
                    if password is not None:
                        payload['password'] = password
                    if salt is not None:
                        payload['salt'] = salt
                    return payload

                to_encrypt = with_password_and_salt({'plaintext': plaintext})
                encrypted = session.encrypt(to_encrypt)
                assert encrypted['ciphertext'] != plaintext
                if salt is None and last_generated_salt:
                    assert encrypted['salt'] != last_generated_salt

                to_decrypt = with_password_and_salt(encrypted)
                decrypted = session.decrypt(to_decrypt)
                assert decrypted['plaintext'] == plaintext
                if salt is not None:
                    last_generated_salt = encrypted['salt']

def test_watch_only(session):
    """Test you can pass your own password in watch only mode"""
    MNEMONIC = 'front strategy cry chronic base table divide zero ' \
               'spoon honey treat fatal cycle list soda iron copper ' \
               'mixed dizzy october math size country check'
    PASSWORD = binascii.hexlify("The password")
    PLAINTEXT = "One two three four five six seven eight nine ten"
    session.register_user(MNEMONIC).login(MNEMONIC, '')
    session.set_watch_only("username", "password")
    del session
    session = Session('localtest', '', False, False)
    session.login_watch_only("username", "password")

    encrypted = session.encrypt({'plaintext': PLAINTEXT, 'password': PASSWORD})
    assert encrypted['ciphertext'] != PLAINTEXT
    assert 'password' not in encrypted
    assert PASSWORD not in str(encrypted)
    to_decrypt = encrypted
    to_decrypt.update({'password': PASSWORD})
    to_decrypt = session.decrypt(to_decrypt)
    assert to_decrypt['plaintext'] == PLAINTEXT

    # Watch only must provide a password
    for fn in [lambda session: session.encrypt({'plaintext': PLAINTEXT}),
               lambda session: session.decrypt(encrypted)]:
        caught = False
        try:
            fn(session)
        except Exception as e:
            caught = True
        assert caught


if __name__ == "__main__":
    test_greenbits_testvector(Session('localtest', '', False, False))
    test_roundtrips(Session('localtest', '', False, False))
    test_watch_only(Session('localtest', '', False, False))
