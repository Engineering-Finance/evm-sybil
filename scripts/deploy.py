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

    print("deploy sybil")
    sybil_impl = Sybil.deploy({'from': acct})
    print("SYBIL=", sybil_impl.address)

    print("deploy proxy")
    proxy_sybil = ProxySybil.deploy({'from': acct})
    proxy_sybil.change(sybil_impl.address, {'from': acct})

    print("deploy adapter")
    adapter = SybilOracleAdapter.deploy(proxy_sybil.address, {'from': acct})

    print('------------------------------------------------------')
    print("SYBIL=", sybil_impl.address)
    print("SYBIL_IMPL=", sybil_impl.address)
    print("ORACLE=", adapter.address)
    print('------------------------------------------------------')
