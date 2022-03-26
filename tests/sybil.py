# nvm use 14
# brownie test tests/sybil.py -s --network bsc-main-fork --interactive
import pytest
from brownie import *
from brownie import interface
from brownie import exceptions as brownieExceptions

ZERO_ADDRESS = '0x' + '0' * 40

PANCAKESWAP_ROUTER = '0x10ED43C718714eb63d5aA57B78B54704E256024E'
PANCAKESWAP_FACTORY = '0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73'

SUSHISWAP_ROUTER = '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506'
SUSHISWAP_FACTORY = '0xc35DADB65012eC5796536bD9864eD8773aBc74C4'
ETH_UNIT = 10**18

BUSD_ADDRESS = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56'
BETH_ADDRESS = '0x2170Ed0880ac9A755fd29B2688956BD959F933F8'

# BNB / USD	8	0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
usd_price_feed_address = '0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE'


@pytest.fixture
def sybil():
    print("deploy Sybil")
    return accounts[0].deploy(Sybil)


@pytest.fixture
def erc4626():
    print("deploy ERC4626 with WETH as underlying asset")
    return accounts[0].deploy(MockERC4626, "MockERC4626", "MRD4626", 100*10**18, BETH_ADDRESS, 2*10**18)


@pytest.fixture
def fake_usd():
    print("deploy mock ERC20 pegged to USD")
    return accounts[0].deploy(MockERC20, "Fake USD", "FU", 18, 100*10**18)


@pytest.fixture
def some_other_token():
    print("deploy some other token")
    return accounts[0].deploy(MockERC20, "Some other token", "SOT", 18, 100*10**18)


def test_oracle(sybil, erc4626, fake_usd, some_other_token):

    # set usd price feed
    sybil.setCurrency("USD", usd_price_feed_address)

    factory = interface.IUniswapV2Factory(SUSHISWAP_FACTORY)
    router = interface.IUniswapV2Router01(SUSHISWAP_ROUTER)
    print("Router WETH Address", router.WETH())
    print("BUSD Address", BUSD_ADDRESS)

    print("setTokenRouter router")
    tx = sybil.setTokenRouter(BUSD_ADDRESS, SUSHISWAP_ROUTER)

    print('check erc20toV2Router')
    router_address = sybil.erc20toV2Router(BUSD_ADDRESS)
    assert(router_address == SUSHISWAP_ROUTER)

    print('get pairs')
    pair_address = factory.getPair(router.WETH(), BUSD_ADDRESS)
    pair = interface.IUniswapV2Pair(pair_address)
    print("pair", pair_address)

    print('get tokens')
    token0 = pair.token0()
    token1 = pair.token1()
    print("token0", token0)
    print("token1", token1)

    print('get liquidity')
    (reserve0, reserve1, blocktimestamp) = pair.getReserves()
    print("reserve0", reserve0, reserve0 / 10**18)
    print("reserve1", reserve1, reserve1 / 10**18)
    print("blocktimestamp", blocktimestamp)

    if token0 == router.WETH():
        print("USD per BNB", reserve1 / reserve0)
    else:
        print("USD per BNB", reserve0 / reserve1)

    print("find out BUSD buy rate")
    price = sybil.getBuyPrice(BUSD_ADDRESS, 10**18)
    print("BNB buy price is", price / 10**18)

    print("find out BUSD sell rate")
    price = sybil.getSellPrice(BUSD_ADDRESS, 10**18)
    print("BNB sell price is", price / 10**18)

    print("find out BUSD sell rate")
    price = sybil.getBuyPriceAs("USD", BUSD_ADDRESS, 10**18)
    print("Buying 1 USD for", price / 10**18)

    print("find out BUSD USD sell rate")
    price = sybil.getSellPriceAs("USD", BUSD_ADDRESS, 10**18)
    print("Selling 1 USD for", price / 10**18)

    print("find out BUSD buy rate in USD")
    price = sybil.getBuyPriceAs("USD", BUSD_ADDRESS, 10**18)
    print("price is", price, price / 10**18)

    print("find out BUSD sell rate")
    price = sybil.getSellPrice(BUSD_ADDRESS, 10**18)
    print("price is", price, price / 10**18)

    print("find out BUSD sell rate in USD")
    price = sybil.getSellPriceAs("USD", BUSD_ADDRESS, 10**18)
    print("price is", price, price / 10**18)

    print("add USD/BNB pair as a LP token")
    if interface.IUniswapV2Pair(pair_address).token0() != BUSD_ADDRESS:
        sybil.setTokenRouter(interface.IUniswapV2Pair(pair_address).token0(), SUSHISWAP_ROUTER)

    if interface.IUniswapV2Pair(pair_address).token1() != BUSD_ADDRESS:
        sybil.setTokenRouter(interface.IUniswapV2Pair(pair_address).token1(), SUSHISWAP_ROUTER)

    sybil.setLPToken(pair_address)

    print("find out total supply")
    total_supply = pair.totalSupply()
    print("total supply:", total_supply / 10**18)

    print("buy price of 1 LP token in BNB")
    price = sybil.getBuyPrice(pair_address, 10**18)
    print("BNB buy price is", price, price / 10**18)

    print("sell price of 1 LP token in BNB")
    price = sybil.getSellPrice(pair_address, 10**18)
    print("BNB sell price is", price, price / 10**18)

    print("buy price of 1 LP token in USD")
    price = sybil.getBuyPriceAs("USD", pair_address, 10**18)
    print("Buying 1 LP token for", price, price / 10**18)

    print("sell price of 1 LP token in USD")
    price = sybil.getSellPriceAs("USD", pair_address, 10**18)
    print("Selling 1 LP token for", price, price / 10**18)
    
    ERC4626_ADDRESS = erc4626.address
    print("ERC4626 Address", ERC4626_ADDRESS)
    
    print("Set ERC4626 as 4626 Token in Sybil")
    sybil.setUnitToken(interface.IERC4626(ERC4626_ADDRESS).asset())
    sybil.setToken4626(ERC4626_ADDRESS)

    print("find out ERC4626 buy rate")
    price = sybil.getBuyPrice(ERC4626_ADDRESS, 10**18)
    print("ERC4626 buy price is", price, price / 10**18)

    print("find out ERC4626 sell rate")
    price = sybil.getSellPrice(ERC4626_ADDRESS, 10**18)
    print("ERC4626 sell price is", price, price / 10**18)

    FU_ADDRESS = fake_usd.address
    print("FakeUSD Address", FU_ADDRESS)

    tx = sybil.setPeggedToken(FU_ADDRESS, "USD")
    print("Set FakeUSD as pegged USD token in Sybil")

    print("find out FakeUSD buy rate")
    price = sybil.getBuyPrice(FU_ADDRESS, 10**18)
    print("FakeUSD buy price is", price, price / 10**18)

    print("find out FakeUSD sell rate")
    price = sybil.getSellPrice(FU_ADDRESS, 10**18)
    print("FakeUSD sell price is", price, price / 10**18)

    print("find out FakeUSD buy rate in USD")
    price = sybil.getBuyPriceAs("USD", FU_ADDRESS, 10**18)
    print("price is", price, price / 10**18)

    print("find out FakeUSD sell rate in USD")
    price = sybil.getSellPriceAs("USD", FU_ADDRESS, 10**18)
    print("price is", price, price / 10**18)

    # create router, stake 1 some_other_token for 2 fake_usd
    some_other_token.approve(router.address, 10*10**18)
    fake_usd.approve(router.address, 20*10**18)
    router.addLiquidity(
        some_other_token.address,
        fake_usd.address,
        10 * 10**18,
        20 * 10**18,
        0,
        0,
        accounts[0],
        chain.time()+1200,
        {'from': accounts[0]}
    )

    # set up sybil for some_other_token, using fake_usd as pivot
    sybil.setTokenPivot(some_other_token.address, SUSHISWAP_ROUTER, FU_ADDRESS)

    print("find out Some Other Token buy rate")
    price = sybil.getBuyPrice(some_other_token.address, 10**18)
    print("Some Other Token buy price is", price, price / 10**18)

    print("find out Some Other Token sell rate")
    price = sybil.getSellPrice(some_other_token.address, 10**18)
    print("Some Other Token sell price is", price, price / 10**18)

    print("find out Some Other Token buy rate in USD")
    price = sybil.getBuyPriceAs("USD", some_other_token.address, 10**18)
    print("price is", price, price / 10**18)

    print("find out Some Other Token sell rate in USD")
    price = sybil.getSellPriceAs("USD", some_other_token.address, 10**18)
    print("price is", price, price / 10**18)


    assert(True)