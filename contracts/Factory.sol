// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.24;

import './Deployer.sol';
import './NoDelegateCall.sol';


/// @title Canonical factory
/// @notice Deploys pools and manages ownership and control over pool protocol fees
contract Factory is NoDelegateCall {
    address public override owner;

    address public immutable dataStore;
    address public immutable reader;
    address public immutable router;
    address public immutable exchangeRouter;
    address public immutable underlyAssetUsd;

    mapping(address => mapping(uint24 => mapping(uint24 => address))) public override getPool;

    constructor(
        address _dataStore,
        address _reader,
        address _router, 
        address _exchangeRouter, 
        address _underlyAssetUsd        
    ) {
        owner = msg.sender;
        dataStore = _dataStore;
        reader = _reader;
        router = _router;
        exchangeRouter = _exchangeRouter;
        underlyAssetUsd = _underlyAssetUsd;        
        emit OwnerChanged(address(0), msg.sender);

    }

    function createPool(
        uint24 healthThrehold,
        uint24 fee
    ) external override noDelegateCall returns (address pool) {
        require(getPool[msg.sender][healthThrehold][fee] == address(0));
        pool = deploy(
            address(this), 
            msg.sender, 
            fee,
            healthThrehold, 
            dataStore,
            reader,
            router,
            exchangeRouter,
            underlyAssetUsd
        );
        getPool[msg.sender][healthThrehold][fee] = pool;
        emit PoolCreated(msg.sender, healthThrehold, fee,  pool);
    }

    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

}
