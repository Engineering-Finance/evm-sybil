// SPDX-License-Identifier: MIXED
pragma solidity >=0.8.10 <0.9.0;
import "./MockERC20.sol";

contract MockERC4626 is MockERC20 {

    address private underlyingAsset = address(0);
    uint256 private underlyingAssetsPerShare = 0;
    uint8 private ourDecimals = 0;
    uint256 internal baseUnit;

    constructor(string memory _name, string memory _symbol, uint _totalSupply, address _asset, uint256 _assetPerShare) MockERC20(_name, _symbol, IERC20(_asset).decimals(), _totalSupply) {
        underlyingAsset = _asset;
        underlyingAssetsPerShare = _assetPerShare;
        baseUnit = 10**IERC20(_asset).decimals();
    }

    function asset() public view returns (address) {
        return underlyingAsset;
    }

    function assetsPerShare() public view returns (uint256) {
        return underlyingAssetsPerShare;
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        assets = shares * assetsPerShare() / baseUnit;
    }
    
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }
}