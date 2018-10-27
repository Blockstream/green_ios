from greenaddress import Session
from core_rpc import *
import time

MNEMONIC = 'inmate surface claim nice enter joke loan allow ' \
    'follow want board meadow sustain twenty clog dial ' \
    'enter arrive boat champion kick cry pig drastic'


def create_tx(session, details):
    tx = dict()
    tx.update(details)
    return session.create_transaction(tx)

def create_tx_and_sign(session, details):
    return session.sign_transaction(create_tx(session, details))

def fund(address, amount):
    sendtomany(address, amount)
    generate(1)
    time.sleep(10) # FIXME

def sweep_private_key(session, private_key, passphrase=None):
    details = {
        'private_key': private_key,
        'fee_rate': 1000
    }
    if passphrase:
        details.update({'passphrase': passphrase})
    tx = create_tx_and_sign(session, details)
    sendrawtransaction(tx['transaction'])
    generate(1)
    time.sleep(10) # FIXME

def do_test(network, debug):

    # Connect, register and login our test session
    session = Session(network, '', False, debug).register_user(MNEMONIC).login(MNEMONIC)

    # TODO: replace with wally code. needs gdk build changes
    private_key_bip38 = "6PYTh1Jgj3caimSrFjsfR5wJ8zUgWNDiPoNVZapSy8BwkF4NaKa1R32CaN"

    private_keys = ["cRnGftDGacaz2PAeoM9G37nSfpxuXxo8xByCujgo4d6WHeZmUKra", # compressed/uncompressed wif
                    "92Y6pKrTBnfxy3kshrsoubAPaigQEMoFVN4fwzhjcFyXeqfaRfX"]

    addresses = ["ms8vChacoVXEc77Q8WMUjD6SMx462Khg8g", # compressed/uncompressed
                 "mzfd8oGMaaVA3ErcTZehLTDkNgySScWDsT"]

    # WIF
    fund(addresses, [0.2, 0.1])

    # sweep keys
    for private_key in private_keys:
        sweep_private_key(session, private_key)

    # BIP38
    fund(addresses, [0.2, 0.1])

    private_key = "6PYTh1Jgj3caimSrFjsfR5wJ8zUgWNDiPoNVZapSy8BwkF4NaKa1R32CaN" # compressed bip38
    sweep_private_key(session, private_key, 'passphrase')


if __name__ == "__main__":
    do_test('localtest', False)
