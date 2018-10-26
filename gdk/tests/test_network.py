from greenaddress import get_networks, register_network

def do_test():
    all_networks = ['mainnet', 'testnet', 'regtest', 'localtest']

    # Check default networks are there
    networks = get_networks()
    assert len(networks['all_networks']) == len(all_networks)

    for network in all_networks:
        assert network in networks['all_networks']
        assert networks[network]['network'] == network

    # Check we can register new ones without impacting exising ones
    new_localtest = networks['localtest']
    new_url = 'ws://127.0.0.1:8080/v2/ws'
    new_localtest['wamp_url'] = new_url
    register_network('new_localtest', new_localtest)
    networks = get_networks()
    assert len(networks['all_networks']) == len(all_networks) + 1
    assert networks['localtest']['wamp_url'] != new_url
    assert networks['new_localtest']['wamp_url'] == new_url

    # We can also overwrite existing ones
    register_network('localtest', new_localtest)
    networks = get_networks()
    assert networks['localtest']['wamp_url'] == new_url

    # And delete them
    register_network('localtest', {})
    networks = get_networks()
    assert len(networks['all_networks']) == len(all_networks)
    assert 'localtest' not in networks['all_networks']
    assert 'localtest' not in networks


if __name__ == "__main__":
    do_test()
