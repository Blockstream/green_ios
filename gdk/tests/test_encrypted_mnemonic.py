from greenaddress import Session

MNEMONIC = 'front strategy cry chronic base table divide zero ' \
           'spoon honey treat fatal cycle list soda iron copper ' \
           'mixed dizzy october math size country check'

PASSWORD = 'password'

# ENCRYPTED_MNEMONIC is taken from the javascript/electron wallet so that whatever is
# implemeted in the gdk matches that implementation
ENCRYPTED_MNEMONIC = 'skirt tower mind buffalo uniform venue ' \
                     'pizza hawk police interest host tourist ' \
                     'glory depth quote glimpse utility flat ' \
                     'useful ivory bargain enact attend midnight ' \
                     'boil spirit badge'

def do_test(network, debug):

    for credentials in [(MNEMONIC, ''), (ENCRYPTED_MNEMONIC, PASSWORD)]:

        session = Session(network, '', False, debug).register_user(MNEMONIC).login(*credentials)

        plaintext_mnemonic = session.get_mnemonic_passphrase('')
        assert plaintext_mnemonic == MNEMONIC
        assert len(plaintext_mnemonic.split()) == 24

        encrypted_mnemonic = session.get_mnemonic_passphrase(PASSWORD)
        assert encrypted_mnemonic == ENCRYPTED_MNEMONIC
        assert len(encrypted_mnemonic.split()) == 27


if __name__ == "__main__":
    do_test('localtest', False)
