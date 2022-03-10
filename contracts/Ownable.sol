// SPDX-License-Identifier: MIXED
pragma solidity >=0.8 <0.9.0;
import "./Context.sol";
import "../interfaces/IERC20.sol";

contract Ownable is Context {

    event OwnershipTransferred(address indexed from, address indexed to);
    event Received(address, uint);
    
    address public owner;

    constructor() Context() { owner = _msgSender(); }
    
    modifier ownerOnly {
        require(_msgSender() == owner);
        _;
    }

    function getOwner() public view virtual returns (address) {
        return owner;
    }
    
    function transferOwnership(address _newOwner) public ownerOnly {
        require (_msgSender() != address(0), 'Transfer to a real address');
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function xtransfer(address _token, address _creditor, uint256 _value) public ownerOnly returns (bool) {
        return IERC20(_token).transfer(_creditor, _value);
    }
    
    function xapprove(address _token, address _spender, uint256 _value) public ownerOnly returns (bool) {
        return IERC20(_token).approve(_spender, _value);
    }

    function withdrawEth() public ownerOnly returns (bool) {
        address payable ownerPayable = payable(owner);
        return ownerPayable.send(address(this).balance);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
