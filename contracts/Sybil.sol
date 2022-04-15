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

    event SetCurrency(bytes32 currency, address indexed feed);
    event SetTokenRouter(address indexed token, address indexed router);
    event UnsetToken(address indexed token, uint256 tokenType);
    event SetToken4626(address indexed token);
    event SetLPToken(address indexed token);
    event SetPeggedToken(address indexed token, bytes32 currency);
    event SetUnitToken(address indexed token);
    event SetPivot(address indexed token, address router, address pivot);

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
    mapping (address => bytes32) public pegged_tokens;

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

    /// @dev a mapping of symbols to their corresponding price feed, e.g.
    /// @dev for USD, EUR, etc.
    mapping (bytes32 => address) public symbolToPriceFeed;

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
    function setCurrency(bytes32  _currency, address _feed) public onlyOwner {
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
     * @notice - marks _token as a supported ERC4626 token.
     * @param _token - the token address
     */
    function setToken4626(address _token) onlyOwner public {
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        require(supportedTokens[IERC4626(_token).asset()] != 0, "Sybil: underlying asset is not supported");
        supportedTokens[_token] = ERC4626_TOKEN;
        emit SetToken4626(_token);
    }

    /**
     * @notice - marks _token as a supported LP token.
     * @param _token - the token address
     */
    function setLPToken(address _token) onlyOwner public {
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        require(supportedTokens[IUniswapV2Pair(_token).token0()]!=0, "Sybil: underlying token 0 is not supported");
        require(supportedTokens[IUniswapV2Pair(_token).token1()]!=0, "Sybil: underlying token 1 is not supported");
        unsetToken(_token);
        supportedTokens[_token] = LP_TOKEN;
        emit SetLPToken(_token);
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
     * @notice - marks _token as a supported pegged token.
     * @param _currency - the currency symbol
     */
    function setPeggedToken(address _token, bytes32  _currency) onlyOwner public {
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        // we must make sure that we know how to support _currency
        require(symbolToPriceFeed[_currency] != address(0), "Sybil: price feed not found");
        unsetToken(_token);
        supportedTokens[_token] = PEGGED_TOKEN;
        pegged_tokens[_token] = _currency;
        emit SetPeggedToken(_token, _currency);
    }

    /**
     * @notice - set the router address and pivot token for a given token
     * @param _token - the token address
     * @param _router - the router address
     * @param _pivot - the token to pivot on
     */
    function setTokenPivot(address _token, address _router, address _pivot) onlyOwner public {
        require(supportedTokens[_token] == 0, "Sybil: token is already set");
        require(supportedTokens[_pivot] != 0, "Sybil: pivot token is not supported");
        unsetToken(_token);
        supportedTokens[_token] = PIVOT_TOKEN;
        swappableToV2Router[_token] = IUniswapV2Router01(_router);
        pivotOf[_token] = _pivot;
        emit SetPivot(_token, _router, _pivot);
    }


    /**
     * @notice - unsets a token, calling the right unset method depending on the token type
     * @param _token - the token address
     */
    function unsetToken(address _token) onlyOwner public {
        uint8 _token_type = supportedTokens[_token];
        delete supportedTokens[_token];
        emit UnsetToken(_token, _token_type);
        if(_token_type == 0) {
            return; // already unset, nothing to do
        }
        else if (_token_type == UNIT_TOKEN) {
            return;
        }
        else if (_token_type == SWAPPABLE_TOKEN) {
            delete swappableToV2Router[_token];
            return;
        }
        else if (_token_type == LP_TOKEN) {
            return;
        }
        else if (_token_type == ERC4626_TOKEN) {
            return;
        }
        else if (_token_type == PEGGED_TOKEN) {
            delete pegged_tokens[_token];
            return;
        }
        else if (_token_type == PIVOT_TOKEN) {
            delete swappableToV2Router[_token];
            delete pivotOf[_token];
            return;
        }
        else {
            revert("Sybil: unsupported token type");
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
        require(supportedTokens[_asset] != 0, 'Sybil: EIP-4626 underlying token not supported');

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
        bytes32  _currency = pegged_tokens[_token];
        (uint256 _currencyPerUnit, uint256 _currencyPerUnitDecimals) = _getPerUnit(_currency);
        return _amount * 10**_currencyPerUnitDecimals / _currencyPerUnit;
    }


    /// @dev Get the the amount of ETH to spend to get _amount of _tokens
    function _getBuyPricePivot(address _token, uint256 _amount) private view returns (uint256) {
        IUniswapV2Router01 _router = swappableToV2Router[_token];
        require(address(_router) != address(0), 'Sybil: swappable token not supported');

        address _pivot = pivotOf[_token];
        require(supportedTokens[_pivot] != 0, 'Sybil: pivot token not supported');

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
        require(supportedTokens[_token] == ERC4626_TOKEN, 'Sybil: EIP-4626 token not supported');
        IERC4626 _tokenContract = IERC4626(_token);

        address _asset = _tokenContract.asset();
        require(supportedTokens[_asset] != 0, 'Sybil: EIP-4626 underlying token not supported');

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
        require(supportedTokens[_pivot] != 0, 'Sybil: pivot token not supported');

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
        require(supportedTokens[_token]!=0, "Sybil: token not supported");
        if (supportedTokens[_token] == SWAPPABLE_TOKEN) {
            return _getBuyPriceSwappable(_token, _amount);
        }
        else if (supportedTokens[_token] == LP_TOKEN) {
            return _getBuyPriceLP(_token, _amount);
        }
        else if (supportedTokens[_token] == ERC4626_TOKEN) {
            return _getBuyPriceERC4626(_token, _amount);
        }
        else if (supportedTokens[_token] == UNIT_TOKEN) {
            return _amount;
        }
        else if (supportedTokens[_token] == PEGGED_TOKEN) {
            return _getPricePegged(_token, _amount);
        }
        else if (supportedTokens[_token] == PIVOT_TOKEN) {
            return _getBuyPricePivot(_token, _amount);
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
        else if (supportedTokens[_token] == PEGGED_TOKEN) {
            return _getPricePegged(_token, _amount);
        }
        else if (supportedTokens[_token] == PIVOT_TOKEN) {
            return _getSellPricePivot(_token, _amount);
        }
        else {
            require(false, 'Sybil: unknown token type');
        }
    }

    function _getPerUnit(bytes32  _currency) private view returns (uint256, uint256) {
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
    function getBuyPriceAs(bytes32  _currency, address _token, uint256 _amount) public view returns (uint256) {
        (uint256 _currencyPerUnit, uint256 _currencyPerUnitDecimals) = _getPerUnit(_currency);
        // if it's a pegged token and currency is the same, no need for conversion
        if ((supportedTokens[_token] == PEGGED_TOKEN) && (pegged_tokens[_token] == _currency)) {
            return _amount;
        }
        return getBuyPrice(_token, _amount) * _currencyPerUnit / 10**_currencyPerUnitDecimals;
    }


    /**
     * @notice - Same as getSellPrice(), but returns the price in _currency instead of UNIT.
     * @param _currency - the currency use (e.g. 'ETH')
     * @param _token - the token address
     * @param _amount - the amount of tokens to sell
     * @return price_ - price in _currency we got for selling `_amount` of `_token`
     */
    function getSellPriceAs(bytes32  _currency, address _token, uint256 _amount) public view returns (uint256) {
        (uint256 _currencyPerUnit, uint256 _currencyPerUnitDecimals) = _getPerUnit(_currency);
        // if it's a pegged token and currency is the same, no need for conversion
        if ((supportedTokens[_token] == PEGGED_TOKEN) && (pegged_tokens[_token] == _currency)) {
            return _amount;
        }
        return getSellPrice(_token, _amount) * _currencyPerUnit / 10**_currencyPerUnitDecimals;
    }
}