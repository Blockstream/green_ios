from greenaddress import Session

MNEMONIC = 'glance foster upset erosion engine vessel power hint note ' \
           'maximum entry hand scheme heavy income brush fiscal method ' \
           'sense baby urban cancel dress only'


def throw(unused=None):
    assert False


def send_requires_2fa(sender, address, amount, select=throw, resolve=throw):
    details = { 'addressees': [{'address': address, 'satoshi': amount}], 'fee_rate': 1000 }
    tx = sender.create_transaction(details)
    tx = sender.sign_transaction(tx)

    try:
        sender.send_transaction(tx).resolve(throw, throw)
        return False  # doesn't require 2fa
    except AssertionError as e:
        return True   # Requires 2fa


def do_test(network, debug):
    sender = Session(network, '', False, debug).register_user(MNEMONIC).login(MNEMONIC)

    address = sender.get_receive_address()

    if len(sender.get_unspent_outputs()) == 0:
        print('no utxos, skipping test. send and confirm coins to {} to enable'.format(address))
        return

    gauth_config = sender.get_twofactor_config()['gauth']
    if gauth_config['enabled']:
        # Disable gauth
        sender.change_settings_twofactor('gauth', {
            'confirmed': False, 'enabled': False, 'data': None
        }).resolve()
        gauth_config = sender.get_twofactor_config()['gauth']

    # Setting tx limits now doesn't require twofactor since none is enabled
    # Set tx limit to $1.50
    limits = { 'is_fiat': True, 'fiat': "1.50" }
    sender.twofactor_change_limits(limits).resolve(throw, throw)
    assert sender.get_twofactor_config()["limits"]["fiat"] == "1.50"
    assert sender.get_twofactor_config()["limits"]["is_fiat"] == True

    # Set tx limit to 5000 satoshi
    limits = { 'is_fiat': False, 'satoshi': 5000 }
    sender.twofactor_change_limits(limits).resolve(throw, throw)
    assert sender.get_twofactor_config()["limits"]["satoshi"] == 5000

    # Enable gauth
    sender.change_settings_twofactor('gauth', {
        'confirmed': True, 'enabled': True, 'data': gauth_config['data']
    }).resolve()

    # Lower tx limit to 4500 satoshi. Since we are lowering the limit, this doesn't need 2fa
    limits['satoshi'] = 4500
    sender.twofactor_change_limits(limits).resolve(throw, throw)
    assert sender.get_twofactor_config()["limits"]["satoshi"] == 4500

    # Increasing the limit requires 2fa
    limits['satoshi'] = 5000
    try:
        sender.twofactor_change_limits(limits).resolve(throw, throw)
        assert False
    except:
        pass
    assert sender.get_twofactor_config()["limits"]["satoshi"] == 4500

    # Sending 6666 requires 2fa
    assert send_requires_2fa(sender, address, 6666)
    # Sending 2000 is under the limit and so doesn't
    assert not send_requires_2fa(sender, address, 2000)
    assert sender.get_twofactor_config()["limits"]["satoshi"] != 4500


if __name__ == '__main__':
    do_test('localtest', False)
