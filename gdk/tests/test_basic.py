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

    # On login, we should have been notified
    for expected_notification in ['twofactor_reset', 'subaccount', 'fees', 'block']:
        event = session.notifications.get_nowait()
        assert event['event'] == expected_notification

    # Try some simple calls
    subaccounts = session.get_subaccounts()
    assert(subaccounts[0]['pointer'] == 0)
    assert('satoshi' in subaccounts[0])

    if len(subaccounts) == 1:
        session.create_subaccount({'name': 'foo', 'type': '2of3'})
        subaccounts = session.get_subaccounts()
        assert subaccounts[1]['name'] == 'foo'

    estimates = session.get_fee_estimates()
    assert len(estimates['fees']) == 25

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
            'fee_rate': estimates['fees'][0],
        }

        old_balance = subaccounts[subaccount]["satoshi"]
        session.set_current_subaccount(subaccount)

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
                    found = True
                    break
            except queue.Empty as e:
                time.sleep(1)

        assert found, 'tx {} not found'.format(txhash)

        # The subaccounts balance should have been updated
        subaccounts = session.get_subaccounts()
        assert not subaccounts[subaccount]['is_dirty']
        new_balance = subaccounts[subaccount]["satoshi"]
        assert new_balance < old_balance


if __name__ == '__main__':
    do_test('localtest', False)
