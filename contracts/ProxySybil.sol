// SPDX-License-Identifier: MIXED
pragma solidity >=0.8.10 <0.9.0;
import "../interfaces/ISybil.sol";
import "./Ownable.sol";


contract ProxySybil is Ownable, ISybil {

    ISybil public sybilImplementation;

    /// @notice `owner` defaults to msg.sender on construction.
    constructor() Ownable() {
    }

    function change(address _newSybil) public onlyOwner {
        sybilImplementation = ISybil(_newSybil);
    }

    function getBuyPrice(address _token, uint256 _amount) public view returns (uint256 price_) {
        return sybilImplementation.getBuyPrice(_token, _amount);
    }

    function getSellPrice(address _token, uint256 _amount) public view returns (uint256 price_) {
        return sybilImplementation.getSellPrice(_token, _amount);
    }

    function getBuyPriceAs(string memory _currency, address _token, uint256 _amount) external view returns (uint256 price_) {
        return sybilImplementation.getBuyPriceAs(_currency, _token, _amount);
    }

    function getSellPriceAs(string memory _currency, address _token, uint256 _amount) external view returns (uint256 price_) {
        return sybilImplementation.getSellPriceAs(_currency, _token, _amount);
    }
}