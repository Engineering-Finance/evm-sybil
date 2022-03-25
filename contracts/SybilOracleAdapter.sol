// SPDX-License-Identifier: MIXED
pragma solidity >=0.8.10 <0.9.0;
import "../interfaces/ISybil.sol";
import "../interfaces/IOracle.sol";
import "./Ownable.sol";


contract SybilOracleAdapter is Ownable, IOracle {

    ISybil public sybil;

    /// @notice `owner` defaults to msg.sender on construction.
    constructor(address _sybil) Ownable() {
        sybil = ISybil(_sybil);
    }

    function change(ISybil _newSybil) public onlyOwner {
        sybil = _newSybil;
    }

    /**
     * @notice - SybilOracleAdapter implements {IOracle} to use on {ISybil} instances.
     * @param _token - token address
     * @param _amount - amount, usually 1**18
     * @param _is_buy - true for buy, false for sell
     * @return - abi encoded data for the oracle
     */
    function getDataParameter(string memory _name, string memory _symbol, address _token, uint256 _amount, bool _is_buy) public pure returns (bytes memory) {
        return abi.encode(_name, _symbol, _token, _amount, _is_buy);
    }

    function get(bytes calldata data) public view returns (bool, uint256) {
        (,, address _token, uint256 _amount, bool _is_buy) = abi.decode(data, (string, string, address, uint256, bool));
        if (_is_buy) {
            return (true, sybil.getBuyPrice(_token, _amount));
        }
        else {
            return (true, sybil.getSellPrice(_token, _amount));
        }
    }

    // peek and peekSpot are just aliases for get
    function peek(bytes calldata data) external view returns (bool, uint256) {
        return get(data);
    }

    // peek and peekSpot are just aliases for get
    function peekSpot(bytes calldata data) external view returns (uint256) {
        (, uint256 price) = get(data);
        return price;
    }
    
    function name(bytes calldata data) external pure returns (string memory name_) {
        (name_,,,,) = abi.decode(data, (string, string, address, uint256, bool));
    }

    function symbol(bytes calldata data) external pure returns (string memory symbol_) {
        (symbol_,,,,) = abi.decode(data, (string, string, address, uint256, bool));
    }
}