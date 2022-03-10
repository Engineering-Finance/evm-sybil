// SPDX-License-Identifier: MIXED
pragma solidity >=0.8.10 <0.9.0;

interface ISybil {    

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
     * @param _currency - the currency use (e.g. 'ETH')
     * @param _token - the token address
     * @param _amount - the amount of tokens to buy
     * @return price_ - price in _currency to buy `_amount` of `_token`
     */
    function getBuyPriceAs(string memory _currency, address _token, uint256 _amount) external view returns (uint256 price_);

    /**
     * @notice - Same as getSellPrice(), but returns the price in _currency instead of UNIT.
     * @param _currency - the currency use (e.g. 'ETH')
     * @param _token - the token address
     * @param _amount - the amount of tokens to sell
     * @return price_ - price in _currency to buy `_amount` of `_token`
     */
    function getSellPriceAs(string memory _currency, address _token, uint256 _amount) external view returns (uint256 price_);
}