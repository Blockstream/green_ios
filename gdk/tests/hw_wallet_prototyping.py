""" NOTE: Requires wally in a venv until GDK exports the wally endpoints """
from greenaddress import Session, json
import wallycore as wally

MNEMONIC = 'leopard alien speak merit record sauce stamp never dwarf way ' \
           'prison fan vital arrest bamboo melody wealth spice eyebrow ' \
           'attend volcano public rhythm tortoise'


def throw(unused=None):
    assert False


class wally_device(object):

    def __init__(self):
        _, seed = wally.bip39_mnemonic_to_seed512(MNEMONIC, None)
        self.m = wally.bip32_key_from_seed(seed, wally.BIP32_VER_TEST_PRIVATE, wally.BIP32_FLAG_SKIP_HASH)

    def as_xpub(self, path):
        flags = wally.BIP32_FLAG_KEY_PRIVATE | wally.BIP32_FLAG_SKIP_HASH
        hdkey = self.m
        if len(path):
            hdkey = wally.bip32_key_from_parent_path(hdkey, path, flags)
        xpub = wally.bip32_key_serialize(hdkey, wally.BIP32_FLAG_KEY_PUBLIC)
        return wally.base58check_from_bytes(xpub)

    def get_xpubs(self, required_data):
        return json.dumps({'xpubs': [self.as_xpub(p) for p in required_data['paths']]})

    def sign_message(self, required_data):
        flags = wally.BIP32_FLAG_KEY_PRIVATE | wally.BIP32_FLAG_SKIP_HASH
        hdkey = wally.bip32_key_from_parent_path(self.m, required_data['path'], flags)

        hash_ = wally.format_bitcoin_message(required_data['message'].encode("ascii"), wally.BITCOIN_MESSAGE_FLAG_HASH)
        priv_key = wally.bip32_key_get_priv_key(hdkey)
        sig_der = wally.ec_sig_to_der(wally.ec_sig_from_bytes(priv_key, hash_, wally.EC_FLAG_ECDSA))
        return json.dumps({'signature': wally.hex_from_bytes(sig_der)})



WALLY_DEVICE = wally_device()


def hw_resolver(required_data):
    assert required_data['device']['name'] == 'wally_device'
    return getattr(WALLY_DEVICE, required_data['action'])(required_data)


def do_test(network, debug):
    # Connect, our test session
    session = Session(network, '', False, debug)

    hw_info = {
        # Device details and capabilities:
        'device': {
            'name': 'wally_device',
            'supports_low_r': False
        },
    }

    # Register
    session.register_user_with_hardware(hw_info).resolve(throw, hw_resolver)

    # Login
    session.login_with_hardware(hw_info).resolve(throw, hw_resolver)

    subaccounts = session.get_subaccounts()
    if len(subaccounts) == 1:
        # Create a subaccount in another session
        sw_session = Session(network, '', False, debug).login(MNEMONIC)
        sw_session.create_subaccount({'name': 'foo', 'type': '2of3'})
        # Recreate the H/W session
        session = Session(network, '', False, debug)
        session.login_with_hardware(hw_info).resolve(throw, hw_resolver)
        subaccounts = session.get_subaccounts()

    for subaccount in [0, 1]:
        address = session.get_receive_address(subaccount)
        assert len(address) > 0

        # FIXME: fund address automatically using core or faucet
        unspent_outputs = session.get_unspent_outputs(subaccount)
        transactions = session.get_transactions(subaccount)

        if len(unspent_outputs) == 0:
            type_ = subaccounts[subaccount]['type']
            print('no utxos, skipping {} test. send and confirm coins to {} to enable'.format(type_, address))
            continue

        details = {
            'addressees': [{'address': address, 'satoshi': 6666}],
            'fee_rate': 5000,
        }

        session.set_current_subaccount(subaccount)
        tx = session.create_transaction(details)
        #print tx
        #tx = session.sign_transaction(tx)
        #tx = session.send_transaction(tx).resolve()
        #txhash = tx['txhash']


if __name__ == '__main__':
    do_test('localtest', False)
