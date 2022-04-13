// SPDX-License-Identifier: MIXED
pragma solidity >=0.8.10 <0.9.0;

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

    event SetCurrency(string currency, address indexed feed);
    event SetTokenRouter(address indexed token, address indexed router);
    event UnsetTokenRouter(address indexed token);
    event SetToken4626(address indexed token);
    event UnsetToken4626(address indexed token);
    event SetLPToken(address indexed token);
    event UnsetLPToken(address indexed token);
    event SetPeggedToken(address indexed token, string currency);
    event UnsetPeggedToken(address indexed token);
    event SetUnitToken(address indexed token);
    event UnsetUnitToken(address indexed token);
    event SetPivot(address indexed token, address router, address pivot);
    event UnsetPivot(address indexed token);

    struct LPData {
        address lpToken0;
        address lpToken1;
        uint bToken0; 
        uint bToken1; 
        uint32 blockTimestampLast;
    }

    /// @dev mapping of swappable tokens to their uniswap routers
    mapping (address => IUniswapV2Router01) public swappableToV2Router;

    /// @dev mapping of peggie tokens to their currency peg counterpart
    mapping (address => string) public pegged_tokens;

    uint8 UNIT_TOKEN = 1;
    uint8 SWAPPABLE_TOKEN = 2;
    uint8 LP_TOKEN = 3;
    uint8 ERC4626_TOKEN = 4;
    uint8 PEGGED_TOKEN = 5;
    uint8 PIVOT_TOKEN = 6;

    /// @dev mapping of supported token 
    /// @dev 1 for unit token / tokens which don't require any conversion
    /// @dev 2 for *SWAP token
    /// @dev 3 for LP tokens
    /// @dev 4 for EIP-4626 tokens to boolean indicating whether they are supported
    /// @dev 5 for pegged tokens which are pegged to a currency
    /// @dev 6 for *SWAP tokens that swap with other tokens, not BNB
    mapping (address => uint8) public supportedTokens;

    // mapping (address => bool) public is4626;

    /// @dev mapping of LP tokens to boolean indicating whether they are supported
    //mapping (address => bool) public isLPToken;

    /// @dev mapping of UNIT / 
    //mapping (address => bool) public isUnitToken;

    /// @dev a mapping of symbols to their corresponding price feed, e.g.
    /// @dev for USD, EUR, etc.
    mapping (string => address) public symbolToPriceFeed;

    /// @dev a mapping of tokens to their corresponding pivots, in case
    /// @dev there is no corresponding ETH/BNB pool
    mapping (address => address) public pivotOf;

    /// @notice `owner` defaults to msg.sender on construction.
    constructor() Ownable() {
    }

    /**
     * @notice - sets a currency symbol => price feed mapping
     * @param _currency - the currency symbol
     * @param _feed - the address of the price feed contract
     */
    function setCurrency(string memory _currency, address _feed) public onlyOwner {
        address _old_feed = symbolToPriceFeed[_currency];
        symbolToPriceFeed[_currency] = _feed;
        emit SetCurrency(_currency, _feed);
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
     * @notice - is the asset a supported swappable token?
     * @param _token - the token address
     * @return is_supported_ - true if the token is supported, false otherwise
     */
    function isSwappableAsset(address _token) public view returns (bool) {
        return supportedTokens[_token] == SWAPPABLE_TOKEN;
    }

    /**
     * @notice - is the asset a supported ERC4626 token?
     * @param _token - the token address
     * @return is_supported_ - true if the token is supported, false otherwise
     */
    function is4626Asset(address _token) public view returns (bool) {
        return supportedTokens[_token] == ERC4626_TOKEN;
    }

    /**
     * @notice - is the asset a supported LP token?
     * @param _token - the token address
     * @return is_supported_ - true if the token is supported, false otherwise
     */
    function isLPAsset(address _token) public view returns (bool) {
        return supportedTokens[_token] == LP_TOKEN;
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
     * @notice - is the asset a pegged token?
     * @param _token - the token address
     * @return is_supported_ - true if the token is pegged token, false otherwise
     */
    function isPeggedAsset(address _token) public view returns (bool) {
        return supportedTokens[_token] == PEGGED_TOKEN;
    }

    /**
     * @notice - is the asset a pivot token?
     * @param _token - the token address
     * @return is_supported_ - true if the token is pivot token, false otherwise
     */
    function isPivotAsset(address _token) public view returns (bool) {
        return supportedTokens[_token] == PIVOT_TOKEN;
    }

    /**
     * @notice - is the asset supported at all?
     * @param _token - the token address
     * @return is_supported_ - true if the token is supported, false otherwise
     */
    function isSupportedAsset(address _token) public view returns (bool) {
        return supportedTokens[_token] !=0;
    }

    /**
     * @notice - set the router address for a given swappable token
     * @param _token - the token address
     * @param _router - the router address
     */
    function setTokenRouter(address _token, address _router) onlyOwner public {
        unsetToken(_token);
        supportedTokens[_token] = SWAPPABLE_TOKEN;
        swappableToV2Router[_token] = IUniswapV2Router01(_router);
        emit SetTokenRouter(_token, _router);
    }

    /**
     * @notice - unsets the router address for a given swappable token
     * @param _token - the token address
     */
    function unsetTokenRouter(address _token) onlyOwner public {
        require(supportedTokens[_token] == SWAPPABLE_TOKEN, "Sybil: unsetTokenRouter: not swappable");
        delete supportedTokens[_token];
        delete swappableToV2Router[_token];
        emit UnsetTokenRouter(_token);
    }


    /**
     * @notice - marks _token as a supported ERC4626 token.
     * @param _token - the token address
     */
    function setToken4626(address _token) onlyOwner public {
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        require(isSupportedAsset(IERC4626(_token).asset()), "Sybil: underlying asset is not supported");
        supportedTokens[_token] = ERC4626_TOKEN;
        emit SetToken4626(_token);
    }

    /**
     * @notice - unmarks _token as a supported ERC4626 token.
     * @param _token - the token address
     */
    function unsetToken4626(address _token) onlyOwner public {
        require(supportedTokens[_token] == ERC4626_TOKEN, "Sybil: token is already unset or not set as ERC4626");
        unsetToken(_token);
        delete supportedTokens[_token];
        emit UnsetToken4626(_token);
    }

    /**
     * @notice - marks _token as a supported LP token.
     * @param _token - the token address
     */
    function setLPToken(address _token) onlyOwner public {
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        require(isSupportedAsset(IUniswapV2Pair(_token).token0()), "Sybil: underlying token 0 is not supported");
        require(isSupportedAsset(IUniswapV2Pair(_token).token1()), "Sybil: underlying token 1 is not supported");
        unsetToken(_token);
        supportedTokens[_token] = LP_TOKEN;
        emit SetLPToken(_token);
    }

    /**
     * @notice - unmarks _token as a supported LP token.
     * @param _token - the token address
     */
    function unsetLPToken(address _token) onlyOwner public {
        require(supportedTokens[_token] == LP_TOKEN, "Sybil: token is already unset or not set as LP Token");
        delete supportedTokens[_token];
        emit UnsetLPToken(_token);
    }

    /**
     * @notice - marks _token as a supported unit token.
     * @param _token - the token address
     */
    function setUnitToken(address _token) onlyOwner public {
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        unsetToken(_token);
        supportedTokens[_token] = UNIT_TOKEN;
        emit SetUnitToken(_token);
    }

    /**
     * @notice - unmarks _token as a supported unit token.
     * @param _token - the token address
     */
    function unsetUnitToken(address _token) onlyOwner public {
        require(supportedTokens[_token] == UNIT_TOKEN, "Sybil: unit token is already unset or not set as UNIT TOKEN");
        delete supportedTokens[_token];
        emit UnsetUnitToken(_token);
    }

    /**
     * @notice - marks _token as a supported pegged token.
     * @param _currency - the currency symbol
     */
    function setPeggedToken(address _token, string memory _currency) onlyOwner public {
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        // we must make sure that we know how to support _currency
        require(symbolToPriceFeed[_currency] != address(0), "Sybil: price feed not found");
        unsetToken(_token);
        supportedTokens[_token] = PEGGED_TOKEN;
        pegged_tokens[_token] = _currency;
        emit SetPeggedToken(_token, _currency);
    }

    /**
     * @notice - unmarks _token as a supported pegged token.
     * @param _token - the token address
     */
    function unsetPeggedToken(address _token) onlyOwner public {
        require(supportedTokens[_token] == PEGGED_TOKEN, "Sybil: token is already unset or not set as PEGGED TOKEN");
        delete supportedTokens[_token];
        delete pegged_tokens[_token];
        emit UnsetPeggedToken(_token);
    }

    /**
     * @notice - set the router address and pivot token for a given token
     * @param _token - the token address
     * @param _router - the router address
     * @param _pivot - the token to pivot on
     */
    function setTokenPivot(address _token, address _router, address _pivot) onlyOwner public {
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        require(isSupportedAsset(_pivot), "Sybil: pivot token is not supported");
        unsetToken(_token);
        supportedTokens[_token] = PIVOT_TOKEN;
        swappableToV2Router[_token] = IUniswapV2Router01(_router);
        pivotOf[_token] = _pivot;
        emit SetPivot(_token, _router, _pivot);
    }

    /**
     * @notice - unset the router address and pivot token for a given token
     * @param _token - the token address
     */
    function unsetTokenPivot(address _token) onlyOwner public {
        require(supportedTokens[_token] == PIVOT_TOKEN, "Sybil: token is already unset or not set as PIVOT TOKEN");
        delete supportedTokens[_token];
        delete swappableToV2Router[_token];
        delete pivotOf[_token];
        emit UnsetPivot(_token);
    }

    /**
     * @notice - unsets a token, calling the right unset method depending on the token type
     * @param _token - the token address
     */
    function unsetToken(address _token) onlyOwner public {
        uint8 _token_type = supportedTokens[_token];
        if(_token_type == 0) {
            return; // already unset, nothing to do
        }
        else if (_token_type == UNIT_TOKEN) {
            unsetUnitToken(_token);
        }
        else if (_token_type == SWAPPABLE_TOKEN) {
            unsetTokenRouter(_token);
        }
        else if (_token_type == LP_TOKEN) {
            unsetLPToken(_token);
        }
        else if (_token_type == ERC4626_TOKEN) {
            unsetToken4626(_token);
        }
        else if (_token_type == PEGGED_TOKEN) {
            unsetPeggedToken(_token);
        }
        else if (_token_type == PIVOT_TOKEN) {
            unsetTokenPivot(_token);
        }
        else {
            require(false, "Sybil: unsupported token type");
        }
    }


    /// @dev Get the the amount of ETH to spend to get _amount of swappable _tokens
    function _getBuyPriceSwappable(address _token, uint256 _amount) private view returns (uint256) {
        IUniswapV2Router01 _router = swappableToV2Router[_token];
        require(address(_router) != address(0), 'Sybil: swappable token not supported');
        
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


    /// @dev Get the the amount of ETH to spend to get _amount of ERC4626 _tokens
    function _getBuyPriceERC4626(address _token, uint256 _amount) private view returns (uint256) {
        require(supportedTokens[_token] == ERC4626_TOKEN, 'Sybil: EIP-4626 token not supported');
        IERC4626 _tokenContract = IERC4626(_token);

        address _asset = _tokenContract.asset();
        require(isSupportedAsset(_asset), 'Sybil: EIP-4626 underlying token not supported');

        // return rate of underlying token
        return getBuyPrice(_asset, _tokenContract.previewRedeem(_amount));
    }


    /// @dev Get the the amount of underlying token to spend to get _amount of LP _tokens
    function _getBuyPriceLP(address _token, uint256 _amount) private view returns (uint256) {
        require(supportedTokens[_token] == LP_TOKEN, 'Sybil: LP token not supported');
        LPData memory _lpdata = _getLPData(_token, _amount);
        return
            getBuyPrice(_lpdata.lpToken0, _lpdata.bToken0) +
            getBuyPrice(_lpdata.lpToken1, _lpdata.bToken1);
    }


    /// @dev Get the the amount of ETH to spend to get _amount of pegged _tokens
    function _getPricePegged(address _token, uint256 _amount) private view returns (uint256) {
        require(supportedTokens[_token] == PEGGED_TOKEN, 'Sybil: pegged token not supported');
        string memory _currency = pegged_tokens[_token];
        (uint256 _currencyPerUnit, uint256 _currencyPerUnitDecimals) = _getPerUnit(_currency);
        return _amount * 10**_currencyPerUnitDecimals / _currencyPerUnit;
    }


    /// @dev Get the the amount of ETH to spend to get _amount of _tokens
    function _getBuyPricePivot(address _token, uint256 _amount) private view returns (uint256) {
        IUniswapV2Router01 _router = swappableToV2Router[_token];
        require(address(_router) != address(0), 'Sybil: swappable token not supported');

        address _pivot = pivotOf[_token];
        require(isSupportedAsset(_pivot), 'Sybil: pivot token not supported');

        address [] memory _path = new address[](2);
        _path[0] = _pivot;
        _path[1] = _token;

        uint256 _pivot_amount = _router.getAmountsIn(_amount, _path)[0];
        return getBuyPrice(_pivot, _pivot_amount);
    }


    /// @dev Get the the amount of ETH gotten when selling _amount of swappable _tokens
    function _getSellPriceSwappable(address _token, uint256 _amount) private view returns (uint256) {
        IUniswapV2Router01 _router = swappableToV2Router[_token];
        require(address(_router) != address(0), 'Sybil: swappable token not supported');

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


    /// @dev Get the the amount of ETH gotten when selling _amount of ERC4626 _tokens
    function _getSellPriceERC4626(address _token, uint256 _amount) private view returns (uint256) {
        require(is4626Asset(_token), 'Sybil: EIP-4626 token not supported');
        IERC4626 _tokenContract = IERC4626(_token);

        address _asset = _tokenContract.asset();
        require(isSupportedAsset(_asset), 'Sybil: EIP-4626 underlying token not supported');

        // return rate of underlying token
        return getSellPrice(_asset, _tokenContract.previewRedeem(_amount));
    }


    /// @dev Get the the amount of underlying token to spend to get _amount of LP _tokens
    function _getSellPriceLP(address _token, uint256 _amount) private view returns (uint256) {
        require(supportedTokens[_token] == LP_TOKEN, 'Sybil: LP token not supported');
        LPData memory _lpdata = _getLPData(_token, _amount);
        return
            getSellPrice(_lpdata.lpToken0, _lpdata.bToken0) +
            getSellPrice(_lpdata.lpToken1, _lpdata.bToken1);
    }

    /// @dev Get the the amount of ETH to spend to get _amount of swappable _tokens
    function _getSellPricePivot(address _token, uint256 _amount) private view returns (uint256) {
        IUniswapV2Router01 _router = swappableToV2Router[_token];
        require(address(_router) != address(0), 'Sybil: swappable token not supported');

        address _pivot = pivotOf[_token];
        require(isSupportedAsset(_pivot), 'Sybil: pivot token not supported');

        address [] memory _path = new address[](2);
        _path[0] = _token;
        _path[1] = _pivot;
        uint256 _pivot_amount = _router.getAmountsOut(_amount, _path)[1];

        return getSellPrice(_pivot, _pivot_amount);
    }


    /**
     * @notice - Return price in UNIT to buy `_amount` of `_token`
     * @param _token - the token address
     * @param _amount - the amount of tokens to buy
     * @return price_ - price in UNIT to buy `_amount` of `_token`
     */
    function getBuyPrice(address _token, uint256 _amount) public view returns (uint256) {
        require(isSupportedAsset(_token), "Sybil: token not supported");
        if (isSwappableAsset(_token)) {
            return _getBuyPriceSwappable(_token, _amount);
        }
        else if (isLPAsset(_token)) {
            return _getBuyPriceLP(_token, _amount);
        }
        else if (is4626Asset(_token)) {
            return _getBuyPriceERC4626(_token, _amount);
        }
        else if (isUnitAsset(_token)) {
            return _amount;
        }
        else if (isPeggedAsset(_token)) {
            return _getPricePegged(_token, _amount);
        }
        else if (isPivotAsset(_token)) {
            return _getBuyPricePivot(_token, _amount);
        }
        else {
            require(false, 'Sybil: unknown token type');
        }

        // cannot reach, get rid of silly warning
        return 0;
    }

    /**
     * @notice - Return the price we get in UNIT for selling `_amount` of `_token`
     * @param _token - the token address
     * @param _amount - the amount of tokens to buy
     * @return price_ - the price we get for selling.
     */
    function getSellPrice(address _token, uint256 _amount) public view returns (uint256) {
        uint256 supportedToken_ = supportedTokens[_token]; 
        require(supportedToken_ !=0, "Token not supported");
        if (supportedToken_ ==  SWAPPABLE_TOKEN){
            return _getSellPriceSwappable(_token, _amount);
        }
        else if (supportedToken_ == LP_TOKEN) {
            return _getSellPriceLP(_token, _amount);
        }
        else if (supportedToken_ == ERC4626_TOKEN) {
            return _getSellPriceERC4626(_token, _amount);
        }
        else if (supportedToken_ == UNIT_TOKEN) {
            return _amount;
        }
        else if (isPeggedAsset(_token)) {
            return _getPricePegged(_token, _amount);
        }
        else if (isPivotAsset(_token)) {
            return _getSellPricePivot(_token, _amount);
        }
        else {
            require(false, 'Sybil: unknown token type');
        }
    }

    function _getPerUnit(string memory _currency) private view returns (uint256, uint256) {
        // make sure symbolToPriceFeed[_currency] isn't null
        require(symbolToPriceFeed[_currency] != address(0), 'Sybil: price feed not found');
        AggregatorV3Interface _pricefeed = AggregatorV3Interface(symbolToPriceFeed[_currency]);
        (,int price,,,) = _pricefeed.latestRoundData();
        return (uint256(price), _pricefeed.decimals());
    }

    /**
     * @notice - Same as getBuyPrice(), but returns the price in _currency instead of UNIT.
     * @param _currency - the currency use (e.g. 'ETH')
     * @param _token - the token address
     * @param _amount - the amount of tokens to buy
     * @return price_ - price in _currency to buy `_amount` of `_token`
     */
    function getBuyPriceAs(string memory _currency, address _token, uint256 _amount) public view returns (uint256) {
        (uint256 _currencyPerUnit, uint256 _currencyPerUnitDecimals) = _getPerUnit(_currency);

        // if it's a pegged token and currency is the same, no need for conversion
        if (isPeggedAsset(_token) && _isEqualStr(pegged_tokens[_token], _currency)) {
            return _amount;
        }

        return getBuyPrice(_token, _amount) * _currencyPerUnit / 10**_currencyPerUnitDecimals;
    }

    function _isEqualStr(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    /**
     * @notice - Same as getSellPrice(), but returns the price in _currency instead of UNIT.
     * @param _currency - the currency use (e.g. 'ETH')
     * @param _token - the token address
     * @param _amount - the amount of tokens to sell
     * @return price_ - price in _currency we got for selling `_amount` of `_token`
     */
    function getSellPriceAs(string memory _currency, address _token, uint256 _amount) public view returns (uint256) {
        (uint256 _currencyPerUnit, uint256 _currencyPerUnitDecimals) = _getPerUnit(_currency);

        // if it's a pegged token and currency is the same, no need for conversion
        if (isPeggedAsset(_token) && _isEqualStr(pegged_tokens[_token], _currency)) {
            return _amount;
        }

        return getSellPrice(_token, _amount) * _currencyPerUnit / 10**_currencyPerUnitDecimals;
    }
}