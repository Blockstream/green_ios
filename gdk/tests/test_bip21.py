from greenaddress import Session

MNEMONIC = 'inmate surface claim nice enter joke loan allow ' \
    'follow want board meadow sustain twenty clog dial ' \
    'enter arrive boat champion kick cry pig drastic'
network = 'localtest'
debug = False
session = Session(network, '', False, debug).register_user(MNEMONIC).login(MNEMONIC)

tx = {'fee_rate': 100}

test_vectors = [
    (
        # Vanilla address and amount
        {'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ', 'btc': '1.1'},
        {
            'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
            'btc': '1.10000000',
            'mbtc': '1100.00000',
            'ubtc': '1100000.00',
            'bits': '1100000.00',
        },
    ),
    (
        # Bip21 with address and amount
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?amount=1.1'},
        {
            'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
            'btc': '1.10000000',
            'mbtc': '1100.00000',
            'ubtc': '1100000.00',
            'bits': '1100000.00',
            'bip21-params': {'amount': '1.1'},
        },
    ),
    (
        # Bip21 with no amount - amount is specific separately
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ', 'btc': '1.1'},
        {
            'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
            'btc': '1.10000000',
            'mbtc': '1100.00000',
            'ubtc': '1100000.00',
            'bits': '1100000.00',
            'bip21-params': None,
        },
    ),
    (
        # Bip21 uri with amount which is repeated explicitly
        # This is allowed just redundant
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?amount=1.1', 'btc': '1.1'},
        {
            'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
            'btc': '1.10000000',
            'mbtc': '1100.00000',
            'ubtc': '1100000.00',
            'bits': '1100000.00',
            'bip21-params': {'amount': '1.1'},
        },
    ),
    (
        # Bip21 with additional parameters
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?amount=1.1&label=foo&foo=bar'},
        {
            'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
            'btc': '1.10000000',
            'mbtc': '1100.00000',
            'ubtc': '1100000.00',
            'bits': '1100000.00',
            'bip21-params': {'amount': '1.1', 'label': 'foo', 'foo' : 'bar'},
        },
    ),
]

for addressee, expected in test_vectors:
    tx['addressees'] = [addressee]
    result = session.create_transaction(tx)
    assert len(result['addressees']) == 1
    for key, value in result['addressees'][0].iteritems():
        if key in expected:
            assert value == expected[key]

errors = [
    (
        {'address': 'xyz', 'btc': '1'},
        "id_invalid_address",
    ),
    (
        {'address': '2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ'},
        "id_no_amount_specified",
    ),
    (
        {'address': 'bitcoin:xyz?amount=1'},
        "id_invalid_address",
    ),
    (
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ'},
        "id_no_amount_specified",
    ),
    (
        {'address': 'bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?req-foo=bar'},
        "id_unknown_bip21_parameter",
    ),
]

for addressee, expected_error in errors:
    tx['addressees'] = [addressee]
    result = session.create_transaction(tx)
    assert result['error'] == expected_error

test_vectors = [
    ('bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?amount=1', {
        u'address': u'2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
        u'amount': u'1',
        }),
    ('bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?amount=1&label=foo', {
        u'address': u'2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
        u'amount': u'1',
        u'label': u'foo',
        }),
    ('bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?amount=1&label=foo&foo=bar', {
        u'address': u'2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
        u'amount': u'1',
        u'label': u'foo',
        u'foo': u'bar',
        }),
    ('bitcoin:mq7se9wy2egettFxPbmn99cK8v5AFq55Lx?amount=0.11&r=https://merchant.com/pay.php?h%3D2a8628fc2fbe', {
        u'r': u'https://merchant.com/pay.php?h%3D2a8628fc2fbe',
        u'address': u'mq7se9wy2egettFxPbmn99cK8v5AFq55Lx',
        u'amount': u'0.11',
        }),
    ('bitcoin:2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ?amount=1.1&label=foo&foo=bar', {
        u'amount': u'1.1',
        u'address': u'2Mv3bRmxxAWTwBLrNEgeAg9HmxQGLurCbsZ',
        u'label': u'foo',
        u'foo': 'bar',
        }),
    ]
