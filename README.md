# evm-sybil
An oracle-like contract that supports ERC20 pools, ERC4636 rebase tokens, and LP tokens

# testing

    nvm use 14
    brownie test tests/sybil.py -s --network bsc-main-fork --interactive

# how to use

After it's been deployed, Sybil needs to be configured with the following:

## ERC-20 tokens

To add support for an ERC20 token, you should point it to the address of the DEX on which
it is traded, e.g.

    accounts[0].deploy(Sybil)
    sybil.setTokenRouter(BUSD_ADDRESS, SUSHISWAP_ROUTER)

## ERC-4626 tokens

ERC4626 tokens are supported so long as their underlying assets are also supported by Sybil.
All you need to do is mark them as supported:

    sybil.setToken4626(MY_4626_ADDRESS, True)

Transaction will revert if underlying tokens are not supported.

## LP Tokens

LP Tokens are supported so long as their underlying assets are also supported by Sybil.
All you need to do is mark them as supported:

    sybil.setTokenLP(MY_LP_ADDRESS, True)

Transaction will revert if underlying tokens are not supported.

## Pegged tokens

Pegged tokens are tokens which have the same value as a given currency. 

Sybil supports AggregatorV3Interface price feeds, so you can request the buy price as a currency.

    sybil.setCurrency("USD", USD_PRICE_FEED)
    sybil.setPeggedToken(MY_USD_ADDRESS, "USD")

## Requesting buy price

Buy price of an asset depends on the price on the amount requested. It is returned in
UNITS, e.g. in ETH on Ethereum, BNB on binance, etc.

    buy_price = sybil.getBuyPrice(BUSD_ADDRESS, 100*10**18)

Sell price of an asset depends on how much you are selling. It is returned in UNITS, e.g. in ETH on Ethereum, BNB on binance, etc.

    sell_price = sybil.getSellPrice(BUSD_ADDRESS, 100*10**18)

## Requesting buy price as a currency

Sybil supports AggregatorV3Interface price feeds, so you can request the buy price as a currency.

Before you do so, you must configure sybil for the currency you want to support by mapping the
currency symbol to its corresponding price feed.

    sybil.setCurrency("USD", USD_PRICE_FEED)

Once that's done, you can pass the currency in the corresponding getBuyPriceAs() and getSellPriceAs()
methods, e.g.

    buy_price_usd = sybil.getBuyPriceAs("USD", BUSD_ADDRESS, 100*10**18)
    sell_price_usd = sybil.getSellPriceAs("USD", BUSD_ADDRESS, 100*10**18)


## ProxySybil

ProxySybil is an ISybil-compatible contract which delegates all its calls to another ISybil contract. This allows you to change the underlying ISybil contract without having to update all your code.

    proxy_sybil = accounts[0].deploy(ProxySybil)
    proxy_sybil.change(sybil.address)


## SybilOracleAdapter

SybilOracleAdapter is a kashi-lending {IOracle} adapter for {ISybil} contracts.
See https://github.com/sushiswap/kashi-lending/blob/master/contracts/flat/PeggedOracleFlat.sol

    adapter = SybilOracleAdapter.deploy(proxy_sybil.address, {'from': acct})