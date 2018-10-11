from greenaddress import Session

MNEMONIC = 'inmate surface claim nice enter joke loan allow ' \
    'follow want board meadow sustain twenty clog dial ' \
    'enter arrive boat champion kick cry pig drastic'

default_details = None


def create_tx(session, details, use_default=True):
    tx = dict()
    tx.update(default_details if use_default else dict())
    tx.update(details)
    return session.create_transaction(tx)


def do_test(network, debug):

    # Connect, register and login our test session
    session = Session(network, '', False, debug).register_user(MNEMONIC).login(MNEMONIC)

    # FIXME: fund address automatically using core or faucet
    unspent_outputs = session.get_unspent_outputs()
    transactions = session.get_transactions()
    address = session.get_receive_address()

    if len(unspent_outputs) == 0:
        print('no utxos, skipping test. send and confirm coins to {} to enable'.format(address))
        return

    global default_details
    default_details = {
        'addressees': [{'address': address, 'satoshi': 6666}],
        'fee_rate': 1000,
    }

    # Below min fee rate
    tx = create_tx(session, {'fee_rate': 0})
    assert len(tx['error'])


if __name__ == "__main__":
    do_test('localtest', False)
