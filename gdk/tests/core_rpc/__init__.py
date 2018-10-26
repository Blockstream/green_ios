import json
import requests

DEFAULT_TIMEOUT = 10

def __get_rpc_request(name):
    return {'json-rpc': '1.0', 'id': name, 'method': name}

def __post(host, port, request):
    headers = {'Authorization': 'Basic YWRtaW4xOjEyMw==',
               'User-Agent': 'GDK',
               'Accept': '*/*'}
    r = requests.post('http://{}:{}'.format(host, port),
                        headers = headers, json = request, timeout = DEFAULT_TIMEOUT)
    r.raise_for_status()
    return r

def __make_sendtomany_request(addresses, amounts):
    request = __get_rpc_request('sendmany')
    if not isinstance(addresses, list):
        addresses = [addresses]
    if not isinstance(amounts, list):
        amounts = [amounts]
    params = dict({(address, amount) for address, amount in zip(addresses, amounts)})
    request['params'] = ['', params]
    return request

def rpc(request, host='localhost', port='19001'):
    return __post(host, port, request)

def rpc_raw(request, host='localhost', port='19001'):
    return __post(host, port, request)

def rpc(name, params, host='localhost', port='19001'):
    request = __get_rpc_request(name)
    request['params'] = params
    return rpc_raw(request, host, port)
    
def generate(blocks):
    if not isinstance(blocks, list):
        blocks = [blocks]
    return rpc('generate', blocks)

def sendtomany(addresses, amounts):
    return rpc_raw(__make_sendtomany_request(addresses, amounts))

def sendrawtransaction(tx):
    if not isinstance(tx, list):
        tx = [tx]
    return rpc('sendrawtransaction', tx)
