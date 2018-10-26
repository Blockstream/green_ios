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

def do_test(network, debug):

    # Connect, register and login our test session
    session = Session(network, '', False, debug).register_user(MNEMONIC).login(MNEMONIC)

    # TODO: replace with wally code. needs gdk build changes
    private_key_wif_compressed = "cRnGftDGacaz2PAeoM9G37nSfpxuXxo8xByCujgo4d6WHeZmUKra"
    compressed_address = "ms8vChacoVXEc77Q8WMUjD6SMx462Khg8g"
    private_key_wif_uncompressed = "92Y6pKrTBnfxy3kshrsoubAPaigQEMoFVN4fwzhjcFyXeqfaRfX"
    uncompressed_address = "mzfd8oGMaaVA3ErcTZehLTDkNgySScWDsT"

    # fund users
    sendtomany(compressed_address, 0.2)
    sendtomany(uncompressed_address, 0.1)
    generate(1)

    # FIXME
    time.sleep(10)

    details = {
        'private_key': private_key_wif_compressed,
        'fee_rate': 1000
    }
    tx = create_tx_and_sign(session, details)
    sendrawtransaction(tx['transaction'])

    details = {
        'private_key': private_key_wif_uncompressed,
        'fee_rate': 1000
    }
    tx = create_tx_and_sign(session, details)
    sendrawtransaction(tx['transaction'])

if __name__ == "__main__":
    do_test('localtest', False)
