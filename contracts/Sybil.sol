// SPDX-License-Identifier: MIXED
pragma solidity >=0.8 <0.9.0;

import "../interfaces/AggregatorV3Interface.sol";
import "../interfaces/IUniswapV2Router01.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IERC4626.sol";
import "../interfaces/ISybil.sol";
import "./Ownable.sol";


/**
 * @title Sybil - Oracle-like contract supporting ERC20, ERC4626 and LP tokens.
 */
contract Sybil is Ownable, ISybil {

    event SetCurrency(string currency, address indexed old_feed, address indexed new_feed);
    event SetTokenRouter(address indexed token, address indexed old_router, address indexed new_router);
    event SetToken4626(address indexed token, bool is_4626);
    event SetLPToken(address indexed token, bool is_lp);
    event SetUnitToken(address indexed token, bool is_unit);

    struct LPData {
        address lpToken0;
        address lpToken1;
        uint bToken0; 
        uint bToken1; 
        uint32 blockTimestampLast;
    }

    /// @dev mapping of ERC-20 tokens to their uniswap routers
    mapping (address => IUniswapV2Router01) public erc20toV2Router;
    uint256 constant UNIT_TOKEN = 1;
    uint256 constant SWAPABLE_TOKEN = 2;
    uint256 constant LP_TOKEN = 3;
    uint256 constant ERC4626_TOKEN = 4;

    /// @dev mapping of supported token 
    /// @dev 1 for unit token / tokens which don't require any conversion
    /// @dev 2 for *SWAP token
    /// @dev 3 for LP tokens
    /// @dev 4 for EIP-4626 tokens to boolean indicating whether they are supported
    mapping (address => uint256) public supportedTokens;
    // mapping (address => bool) public is4626;

    /// @dev mapping of LP tokens to boolean indicating whether they are supported
    //mapping (address => bool) public isLPToken;

    /// @dev mapping of UNIT / 
    //mapping (address => bool) public isUnitToken;

    /// @dev a mapping of symbols to their corresponding price feed, e.g.
    /// @dev for USD, EUR, etc.
    mapping (string => address) public symbolToPriceFeed;

    /// @notice `owner` defaults to msg.sender on construction.
    constructor() Ownable() {
    }

    /**
     * @notice - sets a currency symbol => price feed mapping
     * @param _currency - the currency symbol
     * @param _new_feed - the address of the price feed contract
     */
    function setCurrency(string memory _currency, address _new_feed) public ownerOnly {
        address _old_feed = symbolToPriceFeed[_currency];
        symbolToPriceFeed[_currency] = _new_feed;
        emit SetCurrency(_currency, _old_feed, _new_feed);
    }

    // @dev returns LP data for a given LP token
    function _getLPData(address _token, uint _amount) private view returns (LPData memory lpdata) {
        uint t = IUniswapV2Pair(_token).totalSupply();
        (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) = IUniswapV2Pair(_token).getReserves();
        lpdata.lpToken0 = IUniswapV2Pair(_token).token0();
        lpdata.lpToken1 = IUniswapV2Pair(_token).token1();
        lpdata.bToken0 = _amount * _reserve0 / t;
        lpdata.bToken1 = _amount * _reserve1 / t;
        lpdata.blockTimestampLast = _blockTimestampLast;
    }

    /**
     * @notice - is the asset a supported ERC20 token?
     * @param _token - the token address
     * @return is_supported_ - true if the token is supported, false otherwise
     */
    function isERC20Asset(address _token) public view returns (bool is_supported_) {
        is_supported_ = (supportedTokens[_token] == SWAPABLE_TOKEN);
    }

    /**
     * @notice - is the asset a supported ERC4626 token?
     * @param _token - the token address
     * @return is_supported_ - true if the token is supported, false otherwise
     */
    function is4626Asset(address _token) public view returns (bool is_supported_) {
        is_supported_ = (supportedTokens[_token] == ERC4626_TOKEN);
    }

    /**
     * @notice - is the asset a supported LP token?
     * @param _token - the token address
     * @return is_supported_ - true if the token is supported, false otherwise
     */
    function isLPAsset(address _token) public view returns (bool is_supported_) {
        is_supported_ = (supportedTokens[_token] == LP_TOKEN);
    }

    /**
     * @notice - is the asset a unit token? Meaning ETH on ethereum, BNB on binance, etc.
     * @param _token - the token address
     * @return is_supported_ - true if the token is unit token, false otherwise
     */
    function isUnitAsset(address _token) public view returns (bool) {
        return supportedTokens[_token] == UNIT_TOKEN;
    }

    /**
     * @notice - is the asset supported at all? i.e. either ERC20, ERC4626, or LP token
     * @param _token - the token address
     * @return is_supported_ - true if the token is supported, false otherwise
     */
    function isSupportedAsset(address _token) public view returns (bool) {
        return (supportedTokens[_token] !=0);
    }

    /**
     * @notice - set the router address for a given ERC20 token
     * @param _token - the token address
     * @param _new_router - the router address
     */
    function setTokenRouter (address _token, address _new_router) ownerOnly public {
        uint256 supportedToken_ = supportedTokens[_token];
        require ((supportedToken_ ==0) || (supportedToken_ == SWAPABLE_TOKEN), "Sybil: not swappable");
        if (supportedToken_ == 0) {
            supportedTokens[_token] = SWAPABLE_TOKEN;
        }
        address _old_router = address(erc20toV2Router[_token]);
        require(_old_router != _new_router, "Sybil: new router is the same as the old router");
        erc20toV2Router[_token] = IUniswapV2Router01(_new_router);
        emit SetTokenRouter(_token, _old_router, _new_router);
    }

    /**
     * @notice - marks _token as a supported ERC4626 token.
     * @param _token - the token address
     */
    function setToken4626(address _token) ownerOnly public {
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        require(isSupportedAsset(IERC4626(_token).asset()), "Sybil: underlying asset is not supported");
        supportedTokens[_token] = ERC4626_TOKEN;
        emit SetToken4626(_token, true);
    }

    /**
     * @notice - unmarks _token as a supported ERC4626 token.
     * @param _token - the token address
     */
    function unsetToken4626(address _token) ownerOnly public {
        require(supportedTokens[_token] == ERC4626_TOKEN, "Sybil: token is already unset or not set as ERC4626");
        delete supportedTokens[_token];
        emit SetToken4626(_token, false);
    }

    /**
     * @notice - marks _token as a supported LP token.
     * @param _token - the token address
     */
    function setLPToken(address _token) ownerOnly public {
        // make sure underlying tokens are supported
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        require(isSupportedAsset(IUniswapV2Pair(_token).token0()));
        require(isSupportedAsset(IUniswapV2Pair(_token).token1()));
        supportedTokens[_token] = LP_TOKEN;
        emit SetLPToken(_token, true);
    }

    /**
     * @notice - unmarks _token as a supported LP token.
     * @param _token - the token address
     */
    function unsetLPToken(address _token) ownerOnly public {
        require(supportedTokens[_token] == LP_TOKEN, "Sybil: token is already unset or not set as LP Token");
        delete supportedTokens[_token];
        emit SetLPToken(_token, false);
    }

    /**
     * @notice - marks _token as a supported unit token.
     * @param _token - the token address
     */
    function setUnitToken(address _token) ownerOnly public {
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        supportedTokens[_token] = UNIT_TOKEN;
        emit SetUnitToken(_token, true);
    }

    /**
     * @notice - unmarks _token as a supported unit token.
     * @param _token - the token address
     */
    function unsetUnitToken(address _token) ownerOnly public {
        require(supportedTokens[_token] == UNIT_TOKEN, "Sybil: unit token is already unset or not set as UNIT TOKEN");
        delete supportedTokens[_token];
        emit SetUnitToken(_token, false);
    }

    /// @dev Get the the amount of ETH to spend to get _amount of ERC20 _tokens
    function _getBuyPriceERC20(address _token, uint256 _amount) private view returns (uint256) {
        IUniswapV2Router01 _router = erc20toV2Router[_token];
        require(address(_router) != address(0), 'Sybil: ERC20 token not supported');
        
        if(_router.WETH() == _token) {
            return _amount;
        }
        else {
            address [] memory _path = new address[](2);
            _path[0] = _router.WETH();
            _path[1] = _token;
            return _router.getAmountsIn(_amount, _path)[0];
        }
    }

    /// @dev Get the the amount of underlying token to spend to get _amount of ERC-4626 _tokens
    function _getBuyPriceERC4626(address _token, uint256 _amount) private view returns (uint256) {
        require(supportedTokens[_token] == ERC4626_TOKEN, 'Sybil: EIP-4626 token not supported');
        IERC4626 _tokenContract = IERC4626(_token);

        address _asset = _tokenContract.asset();
        require(isSupportedAsset(_asset), 'Sybil: EIP-4626 underlying token not supported');

        // compute amount of underlying asset
        _amount = _amount * _tokenContract.assetsPerShare() / 10**_tokenContract.decimals();

        // return rate of underlying token
        return getBuyPrice(_asset, _amount);
    }

    /// @dev Get the the amount of underlying token to spend to get _amount of LP _tokens
    function _getBuyPriceLP(address _token, uint256 _amount) private view returns (uint256) {
        require(supportedTokens[_token] == LP_TOKEN, 'Sybil: LP token not supported');
        LPData memory _lpdata = _getLPData(_token, _amount);
        return
            getBuyPrice(_lpdata.lpToken0, _lpdata.bToken0) +
            getBuyPrice(_lpdata.lpToken1, _lpdata.bToken1);
    }

    /// @dev Get the the amount of underlying token to spend to get _amount of LP _tokens
    function _getSellPriceLP(address _token, uint256 _amount) private view returns (uint256) {
        require(supportedTokens[_token] == LP_TOKEN, 'Sybil: LP token not supported');
        LPData memory _lpdata = _getLPData(_token, _amount);
        return
            getSellPrice(_lpdata.lpToken0, _lpdata.bToken0) +
            getSellPrice(_lpdata.lpToken1, _lpdata.bToken1);
    }

    /// @dev Return price in ETH when selling `amount` of `token`
    function _getSellPriceERC20(address _token, uint256 _amount) private view returns (uint256) {
        IUniswapV2Router01 _router = erc20toV2Router[_token];
        require(address(_router) != address(0), 'Sybil: ERC20 token not supported');

        if(_router.WETH() == _token) {
            return _amount;
        }
        else {
            address [] memory _path = new address[](2);
            _path[0] = _token;
            _path[1] = _router.WETH();
            return _router.getAmountsOut(_amount, _path)[1];
        }
    }

    /// @dev Get the the amount of underlying token to spend to get _amount of ERC-4626 _tokens
    function _getSellPriceERC4626(address _token, uint256 _amount) private view returns (uint256) {
        require(is4626Asset(_token), 'Sybil: EIP-4626 token not supported');
        IERC4626 _tokenContract = IERC4626(_token);

        address _asset = _tokenContract.asset();
        require(isSupportedAsset(_asset), 'Sybil: EIP-4626 underlying token not supported');

        // compute amount of underlying asset
        _amount = _amount * _tokenContract.assetsPerShare() / 10**_tokenContract.decimals();

        // return rate of underlying token
        return getSellPrice(_asset, _amount);
    }

    /**
     * @notice - Return price in UNIT to buy `_amount` of `_token`
     * @param _token - the token address
     * @param _amount - the amount of tokens to buy
     * @return price_ - price in UNIT to buy `_amount` of `_token`
     */
    function getBuyPrice(address _token, uint256 _amount) public view returns (uint256 price_) {
        require(isSupportedAsset(_token));
        if (isERC20Asset(_token)) {
            price_ = _getBuyPriceERC20(_token, _amount);
        }
        else if (isLPAsset(_token)) {
            price_ = _getBuyPriceLP(_token, _amount);
        }
        else if (is4626Asset(_token)) {
            price_ = _getBuyPriceERC4626(_token, _amount);
        }
        else if (isUnitAsset(_token)) {
            price_ = _amount;
        }
        else {
            require(false, 'Sybil: unknown token type');
        }
    }

    /**
     * @notice - Return the price we get in UNIT for selling `_amount` of `_token`
     * @param _token - the token address
     * @param _amount - the amount of tokens to buy
     * @return price_ - the price we get for selling.
     */
    function getSellPrice(address _token, uint256 _amount) public view returns (uint256 price_) {
        uint256 supportedToken_ = supportedTokens[_token]; 
        require(supportedToken_ !=0, "Token not supported");
        if (supportedToken_ ==  SWAPABLE_TOKEN){
            price_ = _getSellPriceERC20(_token, _amount);
        }
        else if (supportedToken_ == LP_TOKEN) {
            price_ = _getSellPriceLP(_token, _amount);
        }
        else if (supportedToken_ == ERC4626_TOKEN) {
            price_ = _getSellPriceERC4626(_token, _amount);
        }
        else if (supportedToken_ == UNIT_TOKEN) {
            price_ = _amount;
        }
        else {
            revert('Sybil: unknown token type');
        }
    }

    function _getPerUnit(string memory _currency) private view returns (uint256 price_, uint256 decimals_) {
        // make sure symbolToPriceFeed[_currency] isn't null
        require(symbolToPriceFeed[_currency] != address(0), 'Sybil: price feed not found');
        AggregatorV3Interface _pricefeed = AggregatorV3Interface(symbolToPriceFeed[_currency]);
        (,int price,,,) = _pricefeed.latestRoundData();
        price_ = uint256(price);
        decimals_ = _pricefeed.decimals();
    }

    /**
     * @notice - Same as getBuyPrice(), but returns the price in _currency instead of UNIT.
     * @param _currency - the currency use (e.g. 'ETH')
     * @param _token - the token address
     * @param _amount - the amount of tokens to buy
     * @return price_ - price in _currency to buy `_amount` of `_token`
     */
    function getBuyPriceAs(string memory _currency, address _token, uint256 _amount) public view returns (uint256 price_) {
        (uint256 _currencyPerUnit, uint256 _currencyPerUnitDecimals) = _getPerUnit(_currency);
        price_ = getBuyPrice(_token, _amount) * _currencyPerUnit / 10**_currencyPerUnitDecimals;
    }

    /**
     * @notice - Same as getSellPrice(), but returns the price in _currency instead of UNIT.
     * @param _currency - the currency use (e.g. 'ETH')
     * @param _token - the token address
     * @param _amount - the amount of tokens to sell
     * @return price_ - price in _currency we got for selling `_amount` of `_token`
     */
    function getSellPriceAs(string memory _currency, address _token, uint256 _amount) public view returns (uint256 price_) {
        (uint256 _currencyPerUnit, uint256 _currencyPerUnitDecimals) = _getPerUnit(_currency);
        uint256 unitPrice = getSellPrice(_token, _amount);
        return unitPrice * _currencyPerUnit / 10**_currencyPerUnitDecimals;
    }
}