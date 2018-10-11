from greenaddress import Session, queue, generate_mnemonic, get_random_bytes
import time

MNEMONIC = 'front strategy cry chronic base table divide zero ' \
           'spoon honey treat fatal cycle list soda iron copper ' \
           'mixed dizzy october math size country check'


def do_test(network, debug):
    # generate_mnemonic returns a 24 word seed
    assert(len(generate_mnemonic().split()) == 24)
    # get_random_bytes returns the number requested
    assert(len(get_random_bytes(32)) == 32)

    # Connect, register and login our test session
    session = Session(network, '', False, debug).register_user(MNEMONIC).login(MNEMONIC)

    # Try some simple calls
    subaccounts = session.get_subaccounts()
    assert(subaccounts[0]['pointer'] == 0)

    estimates = session.get_fee_estimates()
    assert len(estimates['fees']) == 25

    address = session.get_receive_address()
    assert len(address) > 0

    # FIXME: fund address automatically using core or faucet
    unspent_outputs = session.get_unspent_outputs()
    transactions = session.get_transactions()

    if len(unspent_outputs) == 0:
        print('no utxos, skipping test. send and confirm coins to {} to enable'.format(address))
        return

    details = {
        'addressees': [{'address': address, 'satoshi': 6666}],
        'fee_rate': estimates['fees'][0],
    }

    tx = session.create_transaction(details)
    tx = session.sign_transaction(tx)
    tx = session.send_transaction(tx).resolve()
    txhash = tx['txhash']

    # Wait for the tx notification
    found = False
    for i in range(60):
        try:
            event = session.notifications.get_nowait()
            if event['event'] == 'transaction' and event['transaction']['txhash'] == txhash:
                print 'Transaction {} processed'.format(txhash)
                found = True
                break
        except queue.Empty as e:
            time.sleep(1)

    assert found, 'tx {} not found'.format(txhash)


if __name__ == "__main__":
    do_test('localtest', False)
