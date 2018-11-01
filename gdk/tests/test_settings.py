from greenaddress import Session

MNEMONIC = 'glance foster upset erosion engine vessel power hint note maximum entry hand scheme '\
           'heavy income brush fiscal method sense baby urban cancel dress only'


def test_notifications_settings(session):

    def _test(settings):
        session.change_settings(settings).resolve()
        assert settings["notifications"] == session.get_settings()["notifications"]

    for settings in [
        {"notifications": {"email_incoming": False}},
        {"notifications": {"email_incoming": True}},
        {"notifications": {"email_incoming": True, "email_outgoing": True}},
        {"notifications": {"email_incoming": True, "email_outgoing": False}},
        {"notifications": {}},
        {"notifications": {"foo": "bar"}},
        ]:
        _test(settings)

def test_pricing_settings(session):

    def _test(settings):
        expected = session.get_settings()["pricing"]
        expected.update(settings.get("pricing", {}))
        session.change_settings(settings).resolve()
        assert session.get_settings()["pricing"] == expected

    for settings in [
        {"pricing": {"currency": "GBP", "exchange": "BITSTAMP"}},
        {"pricing": {"currency": "USD", "exchange": "LOCALBTC"}},
        {},
        {"pricing": {}},
        {"pricing": {"currency": "GBP"}},
        {"pricing": {"exchange": "BITSTAMP"}},
        ]:
        _test(settings)

def do_test(network, debug):
    session = Session(network, '', False, debug).register_user(MNEMONIC).login(MNEMONIC)
    test_notifications_settings(session)
    test_pricing_settings(session)

if __name__ == '__main__':
    do_test('localtest', False)
