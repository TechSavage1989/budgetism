"""Destructive integration contract for a disposable test server only.

Requires a clean, disposable installation, initialized separately before running.
PF_TEST_ALLOW_WRITES=YES PF_TEST_SERVER=http://127.0.0.1:8088
PF_TEST_USERNAME=<owner> PF_TEST_PASSWORD=<password> python3 tests/api_integration.py
"""
import json
import os
import sys
import urllib.error
import urllib.request
import uuid

if os.environ.get('PF_TEST_ALLOW_WRITES') != 'YES':
    sys.exit('Refusing to write test accounts. Set PF_TEST_ALLOW_WRITES=YES on a disposable test database.')
base = os.environ.get('PF_TEST_SERVER', '').rstrip('/')
username = os.environ.get('PF_TEST_USERNAME', '')
password = os.environ.get('PF_TEST_PASSWORD', '')
if not base or not username or not password:
    sys.exit('PF_TEST_SERVER, PF_TEST_USERNAME, and PF_TEST_PASSWORD are required.')


def req(method, route, body=None, token=None, expected=200):
    headers = {'Accept': 'application/json'}
    if token: headers['Authorization'] = 'Bearer ' + token
    data = None
    if body is not None:
        data = json.dumps(body).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    request = urllib.request.Request(base + route, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=12) as response:
            status = response.status
            content = response.read()
    except urllib.error.HTTPError as err:
        status, content = err.code, err.read()
    assert status == expected, f'{route}: got status {status}, wanted {expected}. {content[:300]!r}'
    return json.loads(content) if content else None

req('GET', '/api/accounts', expected=401)
auth = req('POST', '/api/auth/login', {'username': username, 'password': password})
token = auth['token']
uid = uuid.uuid4().hex[:8]

def create_account(name, kind, balance=0):
    return req('POST', '/api/accounts', {'operationId': str(uuid.uuid4()),
               'name': 'Integration ' + uid + ' ' + name,
               'type': kind, 'currency': 'USD', 'openingBalanceMinor': balance},
               token, 201)

checking = create_account('Checking', 'checking', 100000)
savings = create_account('Savings', 'savings')
card = create_account('Credit', 'credit_card')
categories = req('GET', '/api/categories', token=token)
expense = next(c for c in categories if c['kind'] == 'Expense')['id']

def record(kind, source, dest, cents):
    payload = {'operationId': str(uuid.uuid4()), 'kind': kind, 'accountId': source['id'],
               'counterpartyAccountId': dest, 'amountMinor': cents, 'currency': 'USD',
               'effectiveDate': '2026-10-27', 'payee': 'Test ' + kind, 'notes': ''}
    result = req('POST', '/api/transactions', payload, token, 201)
    repeat = req('POST', '/api/transactions', payload, token, 200)
    assert result['id'] == repeat['id'], 'Idempotent retry returned a different transaction'
    payload['amountMinor'] = cents + 1
    req('POST', '/api/transactions', payload, token, 409)

record('expense', checking, expense, 8000)
record('transfer', checking, savings['id'], 20000)
record('expense', card, expense, 12500)
record('transfer', checking, card['id'], 12500)
accounts = {a['id']: a for a in req('GET', '/api/accounts', token=token)}
assert accounts[checking['id']]['balanceMinor'] == 59500
assert accounts[savings['id']]['balanceMinor'] == 20000
assert accounts[card['id']]['balanceMinor'] == 0
snapshot = req('GET', '/api/sync/snapshot', token=token)
assert snapshot['cursor'] > 0
changes = req('GET', '/api/sync/changes?after=0&limit=200', token=token)
assert changes['nextCursor'] > 0
print('PASS: auth, opening balances, expense, transfer, credit payment, idempotency, snapshot, changes')
print('Created disposable test records under marker:', uid)
