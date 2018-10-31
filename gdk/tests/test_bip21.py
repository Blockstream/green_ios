from greenaddress import Session

MNEMONIC = 'inmate surface claim nice enter joke loan allow ' \
    'follow want board meadow sustain twenty clog dial ' \
    'enter arrive boat champion kick cry pig drastic'
network = 'localtest'
debug = False
session = Session(network, '', False, debug).register_user(MNEMONIC).login(MNEMONIC)

test_vectors = [
    (
        # Vanilla address and amount
        {'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ', 'btc': '1.1'},
        {
            u'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
            u'satoshi': 110000000
        },
    ),
    (
        # Bip21 with address and amount
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?amount=1.1'},
        {
            u'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
            u'satoshi': 110000000,
            u'bip21-params': {u'amount': u'1.1'},
        },
    ),
    (
        # Bip21 with no amount - amount is specific separately
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ', 'btc': '1.1'},
        {
            u'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
            u'satoshi': 110000000,
            u'bip21-params': None,
        },
    ),
    (
        # Bip21 uri with amount which is repeated explicitly
        # This is allowed just redundant
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?amount=1.1', 'btc': '1.1'},
        {
            u'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
            u'satoshi': 110000000,
            u'bip21-params': {u'amount': u'1.1'},
        },
    ),
    (
        # Bip21 uri with a different amount than in the addressee directly.
        # The value in the uri is used
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?amount=1.2', 'btc': '1.1'},
        {
            u'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
            u'satoshi': 120000000,
            u'bip21-params': {u'amount': u'1.2'},
        },
    ),
    (
        # Bip21 with additional parameters
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?amount=1.1&label=foo&foo=bar'},
        {
            u'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
            u'satoshi': 110000000,
            u'bip21-params': {u'amount': u'1.1', u'label': u'foo', u'foo' : u'bar'},
        },
    ),
]

for addressee, expected in test_vectors:
    tx = {'fee_rate': 1000, 'addressees': [addressee]}
    result = session.create_transaction(tx)
    returned = result['addressees'][0]
    assert returned == expected

errors = [
    (
        {'address': 'xyz', 'btc': '1'},
        "id_invalid_address",
    ),
    (
        {'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ'},
        "id_invalid_amount",
    ),
    (
        {'address': 'bitcoin:xyz?amount=1'},
        "id_invalid_address",
    ),
    (
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ'},
        "id_invalid_amount",
    ),
    (
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?req-foo=bar'},
        "id_unknown_bip21_parameter",
    ),
]

for addressee, expected_error in errors:
    tx = {'fee_rate': 1000, 'addressees': [addressee]}
    result = session.create_transaction(tx)
    assert result['error'] == expected_error
