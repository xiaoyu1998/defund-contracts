// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import "./Interface.sol";

// @title Reader
// @dev Library for read functions
contract Reader {
    address public immutable dataStore;
    address public immutable reader;

    constructor(
        address _dataStore,
        address _reader
    ){
        dataStore = _dataStore;
        reader = _reader;
    }

    function _getLiquidationHealthFactor() internal view returns (GetLiquidationHealthFactor memory) {
        return IReader(reader).getLiquidationHealthFactor(dataStore, address(this));
    }

    function getPositionsInfo() external view returns (GetPositionInfo[] memory) {
        return IReader(reader).getPositionsInfo(dataStore, address(this));
    }

    function getMarginsAndSupplies() external view returns (GetMarginAndSupply[] memory) {
        return IReader(reader).getMarginsAndSupplies(dataStore, address(this));
    }

    function _getPoolToken(address token) internal view returns (address) {
        return IReader(reader).getPoolToken(dataStore, token);
    }

    function _getPrice(address token) internal view returns (uint256) {
        return IReader(reader).getPrice(dataStore, token);
    }

}
