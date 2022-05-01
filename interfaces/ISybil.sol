// SPDX-License-Identifier: MIXED
pragma solidity >=0.8.10 <0.9.0;

interface ISybil {    

    /**
     * @notice - returns the sybil precision, which should be the same as the current chain.
     */
    function precision() external view returns (uint256);

    /**
     * @notice - return the currency ID of a current string.
     * @param _currency - the currency symbol string
     * @return - the currency ID as a bytes32
     */
    function getCurrencyID(string calldata _currency) external view returns (bytes32);

    /**
     * @notice - Return price in UNIT to buy `_amount` of `_token`
     * @param _token - the token address
     * @param _amount - the amount of tokens to buy
     * @return price_ - price in UNIT to buy `_amount` of `_token`
     */
    function getBuyPrice(address _token, uint256 _amount) external view returns (uint256 price_);

    /**
     * @notice - Return the price we get in UNIT for selling `_amount` of `_token`
     * @param _token - the token address
     * @param _amount - the amount of tokens to buy
     * @return price_ - the price we get for selling.
     */
    function getSellPrice(address _token, uint256 _amount) external view returns (uint256 price_);

    /**
     * @notice - Same as getBuyPrice(), but returns the price in _currency instead of UNIT.
     * @param _currency_id - the currency use (e.g. 'ETH')
     * @param _token - the token address
     * @param _amount - the amount of tokens to buy
     * @return price_ - price in _currency to buy `_amount` of `_token`
     */
    function getBuyPriceAs(bytes32 _currency_id, address _token, uint256 _amount) external view returns (uint256 price_);

    /**
     * @notice - Same as getSellPrice(), but returns the price in _currency instead of UNIT.
     * @param _currency_id - the currency use (e.g. 'ETH')
     * @param _token - the token address
     * @param _amount - the amount of tokens to sell
     * @return price_ - price in _currency to buy `_amount` of `_token`
     */
    function getSellPriceAs(bytes32 _currency_id, address _token, uint256 _amount) external view returns (uint256 price_);
}