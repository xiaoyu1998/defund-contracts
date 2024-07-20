// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.24;

import './NoDelegateCall.sol';
import './ShareToken.sol';
import './Pool.sol';


/// @title Canonical factory
/// @notice Deploys pools and manages ownership and control over pool protocol fees
contract Factory is NoDelegateCall {
    event OwnerChanged(
        address indexed oldOwner, 
        address indexed newOwner
    );
    event PoolCreated(
        address indexed owner,
        address fundStrategy,
        address pool
    );

    address public owner;

    address public immutable dataStore;
    address public immutable reader;
    address public immutable router;
    address public immutable exchangeRouter;
    address public immutable underlyAssetUsd;
    uint256 public immutable decimalsUsd;

    mapping(address => mapping(address => address)) public getPool;

    constructor(
        address _dataStore,
        address _reader,
        address _router, 
        address _exchangeRouter, 
        address _underlyAssetUsd,
        uint256 _decimalsUsd        
    ) {
        owner = msg.sender;
        dataStore = _dataStore;
        reader = _reader;
        router = _router;
        exchangeRouter = _exchangeRouter;
        underlyAssetUsd = _underlyAssetUsd; 
        decimalsUsd = _decimalsUsd;       
        emit OwnerChanged(address(0), msg.sender);
    }

    function createPool(
        address fundStrategy
    ) external noDelegateCall returns (address) {
        require(getPool[msg.sender][fundStrategy] == address(0));

        ShareToken shareToken = new ShareToken();
        Pool pool = new Pool(
            address(this), 
            msg.sender, 
            address(shareToken),
            dataStore,
            reader,
            router,
            exchangeRouter,
            underlyAssetUsd,
            decimalsUsd,
            fundStrategy
        );
        shareToken.transferOwnership(address(pool));
        getPool[msg.sender][fundStrategy] = address(pool);
        emit PoolCreated(msg.sender, address(pool), fundStrategy );

        return address(pool);
    }

    function setOwner(address _owner) external {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

}
