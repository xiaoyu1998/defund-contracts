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

    function getHealthFactor() external view returns (HealthFactor memory) {
        return IReader(reader).getLiquidationHealthFactor(dataStore, address(this));
    }
    
    function getPositions() external view returns (Position[] memory) {
        return IReader(reader).getPositionsInfo(dataStore, address(this));
    }

    function getAssets() external view returns (Asset[] memory) {
        return IReader(reader).getMarginsAndSupplies(dataStore, address(this));
    }

    function _getHealthFactor() internal view returns (HealthFactor memory) {
        return IReader(reader).getLiquidationHealthFactor(dataStore, address(this));
    }

    function _getPoolToken(address token) internal view returns (address) {
        return IReader(reader).getPoolToken(dataStore, token);
    }

    function _getPrice(address token) internal view returns (uint256) {
        return IReader(reader).getPrice(dataStore, token);
    }

    function _getPoolPrice(address token) internal view returns (GetPoolPrice memory) {
        return IReader(reader).getPoolPrice(dataStore, token);
    }

}
