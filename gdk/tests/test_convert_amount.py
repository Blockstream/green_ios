from greenaddress import Session

MNEMONIC = 'camera smooth correct tower rate small provide team donate ' \
           'host forget tag habit radar extend agree guilt nurse valid ' \
           'sweet paddle youth trade keep'


def do_test(network, debug):

    session = Session(network, '', False, debug).register_user(MNEMONIC).login(MNEMONIC)
    convert = lambda details: session.convert_amount(details)

    # Check BTC values are converted and formatted correctly
    values = { 'btc': '1.11100000', 'mbtc': '1111.00000',
               'satoshi': 111100000, 'ubtc': '1111000.00',
               'bits': '1111000.00' }

    for k in values.keys():
        result = convert({k: values[k]})
        for check_k in values.keys():
            assert result[check_k] == values[check_k]

    # Check fiat conversion
    if result['fiat_currency'] == 'USD' and result['fiat_rate'] == '1.1':
        ccy, rate = 'USD', '1.1'
        result = convert({'fiat': '2.22'})
        expected = {'fiat': u'2.22', 'satoshi': 201818181,
                    'btc': '2.01818181', 'fiat_currency': 'USD',
                    'ubtc': '2018181.81', 'fiat_rate': '1.1',
                    'mbtc': '2018.18181', 'bits': u'2018181.81'}
        for check_k in expected.keys():
            assert result[check_k] == expected[check_k]


if __name__ == '__main__':
    do_test('localtest', False)
