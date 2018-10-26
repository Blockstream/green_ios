from greenaddress import Session

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

MNEMONIC = 'inmate surface claim nice enter joke loan allow ' \
    'follow want board meadow sustain twenty clog dial ' \
    'enter arrive boat champion kick cry pig drastic'
network = 'localtest'
debug = False
session = Session(network, '', False, debug).register_user(MNEMONIC).login(MNEMONIC)

for uri, expected in test_vectors:
    tx = session.create_transaction({'fee_rate': 100, 'addressees': [{'address': uri}]})
    assert tx['bip21'] == expected
