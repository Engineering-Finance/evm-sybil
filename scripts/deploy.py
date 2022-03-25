from brownie import *
import os


# check we have the correct environment variables set
try:
    os.environ["WALLET"]
except KeyError:
    print("Please set a WALLET environment variable")
    exit(1)


def main():
    wallet_name = os.environ['WALLET']
    acct = accounts.load(wallet_name)

    sybil_impl = Sybil.deploy({'from': acct})
    print("SYBIL_IMPL=", sybil_impl.address)

    proxy_sybil = ProxySybil.deploy({'from': acct})
    print("SYBIL=", sybil_impl.address)

    proxy_sybil.change(sybil_impl.address, {'from': acct})
    print("Proxy sybil address is set")

    adapter = SybilOracleAdapter.deploy(proxy_sybil.address, {'from': acct})
    print("ORACLE=", adapter.address)