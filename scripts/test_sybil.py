from brownie import *
import os

# check we have the correct environment variables set
try:
    os.environ["PROFILE"]
    os.environ["WALLET"]
    os.environ["ROUTER"]
    os.environ["VOODOO_ADDRESS"]
    os.environ["CIM_ADDRESS"]
    os.environ["VOODOO_CIM_POOL"]
    os.environ["SYBIL_IMPL"]
except KeyError:
    print("Please set the PROFILE, WALLET, ROUTER, VOODOO_ADDRESS, CIM_ADDRESS, VOODOO_CIM_POOL, and SYBIL_IMPL environment variables")
    print("Did you import your profile and wallet properly? e.g. source ~/.blackmagic-devel.env")
    exit(1)

def main():
    wallet_name = os.environ['WALLET']
    acct = accounts.load(wallet_name)

    sybil = Sybil.deploy({'from': acct})
    sybil.setCurrency("USD", os.environ["CHAINLINK_USD_FEED"], {"from": acct})
    sybil.setPeggedToken(os.environ["CIM_ADDRESS"], "USD",  {"from": acct})

    print(sybil.getBuyPrice(os.environ['CIM_ADDRESS'], 10**18, {'from': acct}))
    print(sybil.getSellPrice(os.environ['CIM_ADDRESS'], 10**18, {'from': acct}))