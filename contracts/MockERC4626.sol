// SPDX-License-Identifier: MIXED
pragma solidity >=0.8 <0.9.0;
import "./MockERC20.sol";

contract MockERC4626 is MockERC20 {

    address private underlyingAsset = address(0);
    uint256 private underlyingAssetsPerShare = 0;
    uint8 private ourDecimals = 0;

    constructor(string memory _name, string memory _symbol, uint _totalSupply, address _asset, uint256 _assetPerShare) MockERC20(_name, _symbol, IERC20(_asset).decimals(), _totalSupply) {
        underlyingAsset = _asset;
        underlyingAssetsPerShare = _assetPerShare;
    }

    function asset() public view returns (address) {
        return underlyingAsset;
    }

    function assetsPerShare() public view returns (uint256) {
        return underlyingAssetsPerShare;
    }
}