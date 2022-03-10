// SPDX-License-Identifier: MIXED
pragma solidity >=0.8 <0.9.0;

import "./IERC20.sol";

interface IERC4626 is IERC20 {
    function asset() external view returns (address);
    function maxDeposit(address caller) external view returns (uint256 maxAssets);
    function previewDeposit(uint256 assets) external  returns (uint256 shares);
    function deposit(uint256 assets, address receiver) external  returns (uint256 shares);
    function depositFrom(uint256 assets, address receiver) external  returns (uint256 shares);
    function maxMint(address caller) external view returns (uint256 maxShares);
    function previewMint(uint256 shares) external view returns (uint256 assets);
    function mint(uint256 shares, address receiver) external  returns (uint256 assets);
    function maxWithdraw(address user) external  returns (uint256);
    function previewWithdraw(uint256 amount) external view  returns (uint256);
    function withdraw(uint256 amount, address to, address from) external  returns (uint256 shares);
    function maxRedeem(address user) external  returns (uint256);
    function previewRedeem(uint256 shares) external view  returns (uint256);
    function redeem(uint256 shares, address to, address from) external returns (uint256 amount);
    function assetsOf(address depositor) external view returns (uint256 assets);
    function assetsPerShare() external view returns (uint256 assetsPerUnitShare);
    function totalAssets() external view returns (uint256);
    function addFunds(uint amount) external returns (uint finalAmount);
    function removeFunds(uint amount) external ;
}