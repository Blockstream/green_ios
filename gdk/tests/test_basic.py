from greenaddress import Session, queue, generate_mnemonic, get_random_bytes
import time

MNEMONIC = 'front strategy cry chronic base table divide zero ' \
           'spoon honey treat fatal cycle list soda iron copper ' \
           'mixed dizzy october math size country check'

MNEMONIC2 = 'simple pledge field ghost museum beyond news slab mistake ' \
            'turn fluid circle concert fluid shock timber emotion cage ' \
            'verb scorpion unknown mammal try fox'


def do_test(network, debug, mnemonic, sa):
    # generate_mnemonic returns a 24 word seed
    assert(len(generate_mnemonic().split()) == 24)
    # get_random_bytes returns the number requested
    assert(len(get_random_bytes(32)) == 32)

    # Connect, register and login our test session
    session = Session(network, '', False, debug).register_user(mnemonic).login(mnemonic)

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

    for subaccount in [sa]:
        for bump_within_limits in True, False:
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

            def send_transaction():
                subaccounts = session.get_subaccounts()
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
                bumped = 'previous_transaction' in details
                if bumped:
                    assert new_balance <= old_balance
                else:
                    assert new_balance < old_balance

                return txhash

            # Send initial tx
            txhash = send_transaction()

            # Turn off email 2fa
            try:
                session.change_settings_twofactor("email",
                    {'confirmed': False, 'enabled': False, 'data': "foo@bar.com" }).resolve()
            except Exception as e:
                # FIXME: this is a bit broken
                pass

            # Bump the fee within limits
            limit = 1e8 * 100 if bump_within_limits else 1
            limits = { 'is_fiat': False, 'satoshi': limit }
            session.twofactor_change_limits(limits).resolve()

            # Turn on email 2fa
            try:
                session.change_settings_twofactor("email",
                    {'confirmed': True, 'enabled': True, 'data': "foo@bar.com" }).resolve()
            except Exception as e:
                # Ignore errors due to email already being enabled
                assert str(e) == "email is already enabled"

            # Bump the fee
            txs = session.get_transactions(subaccount, 0)
            previous_tx = None
            for tx in txs['list']:
                if tx['txhash'] == txhash:
                    previous_tx = tx
            assert previous_tx is not None
            assert previous_tx['can_rbf'] == True
            details = {'previous_transaction': previous_tx, 'fee_rate': details['fee_rate'] * 1.5 }
            send_transaction()

if __name__ == '__main__':
    for mnemonic, sa in [(MNEMONIC, 0), (MNEMONIC2, 1)]:
        do_test('localtest', False, mnemonic, sa)
