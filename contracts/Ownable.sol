// SPDX-License-Identifier: MIXED
pragma solidity >=0.6.6 <0.9.0;

contract Ownable {

    // contract owner
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}
