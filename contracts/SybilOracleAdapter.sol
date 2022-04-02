// SPDX-License-Identifier: MIXED
pragma solidity >=0.8.10 <0.9.0;
import "../interfaces/ISybil.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IAggregator.sol";
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
     * @param _name - label of the token
     * @param _symbol - symbol of the token
     * @param _token - token address
     * @param _amount - amount, usually 10**18
     * @param _currency - returns as _currency instead of ETH/BNB
     * @param _multiply - multiplicator
     * @param _divide - divider
     * @return - abi encoded data for the oracle
     */
    function getDataParameter3(
        string memory _name,
        string memory _symbol,
        string memory _currency,
        address _token,
        uint256 _amount,
        uint256 _multiply,
        uint256 _divide
    ) public pure returns (bytes memory) {
        return abi.encode(_name, _symbol, _currency, _token, _amount, _multiply, _divide);
    }

    function getDataParameter2(
        string memory _name,
        string memory _symbol,
        string memory _currency,
        address _token,
        uint256 _amount
    ) public pure returns (bytes memory) {
        return abi.encode(_name, _symbol, _currency, _token, _amount, 1, 1);
    }

    function getDataParameter(
        string memory _name,
        string memory _symbol,
        string memory _currency,
        address _token
    ) public pure returns (bytes memory) {
        return abi.encode(_name, _symbol, _currency, _token, 1e18, 1, 1);
    }

    /** reverse function */
    function parseDataParameter(bytes memory _data) public pure returns (
        string memory _name,
        string memory _symbol,
        string memory _currency,
        address _token,
        uint256 _amount,
        uint256 _multiply,
        uint256 _divide
    ) {
        return abi.decode(_data, (string, string, string, address, uint256, uint256, uint256));
    }

    function _isEqualStr(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function get(bytes calldata _data) public view returns (bool success_, uint256 price_) {
        (,,
            string memory _currency,
            address _token,
            uint256 _amount,
            uint256 _multiply,
            uint256 _divide
        ) = parseDataParameter(_data);

        if(_isEqualStr(_currency, "")) {
            price_ = (
                sybil.getBuyPrice(_token, _amount) +
                sybil.getSellPrice(_token, _amount)
            ) / 2;
        }
        else {
            price_ = (
                sybil.getBuyPriceAs(_currency, _token, _amount) +
                sybil.getSellPriceAs(_currency, _token, _amount)
            ) / 2;
        }

        price_ = price_ * _multiply / _divide;
        return (true, price_);
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