// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.24;

import './NoDelegateCall.sol';
import './ShareToken.sol';
import './Vault.sol';


/// @title Canonical factory
/// @notice Deploys vaults and manages ownership and control over vault protocol fees
contract Factory is NoDelegateCall {
    event OwnerChanged(
        address indexed oldOwner, 
        address indexed newOwner
    );
    event VaultCreated(
        address indexed owner,
        address vaultStrategy,
        address vault
    );

    address public owner;

    address public immutable dataStore;
    address public immutable reader;
    address public immutable router;
    address public immutable exchangeRouter;
    address public immutable tokenUsd;
    uint256 public immutable decimalsUsd;
    uint256 public immutable averageSlippage;

    mapping(address => mapping(address => address)) public getVault;

    constructor(
        address _dataStore,
        address _reader,
        address _router, 
        address _exchangeRouter, 
        address _tokenUsd,
        uint256 _decimalsUsd,     
        uint256 _averageSlippage 
    ) {
        owner = msg.sender;
        dataStore = _dataStore;
        reader = _reader;
        router = _router;
        exchangeRouter = _exchangeRouter;
        tokenUsd = _tokenUsd; 
        decimalsUsd = _decimalsUsd; 
        averageSlippage = _averageSlippage;    
        emit OwnerChanged(address(0), msg.sender);
    }

    function createVault(
        address vaultStrategy
    ) external noDelegateCall returns (address) {
        require(getVault[msg.sender][vaultStrategy] == address(0));

        ShareToken shareToken = new ShareToken();
        Vault vault = new Vault(
            address(this), 
            msg.sender, 
            address(shareToken),
            dataStore,
            reader,
            router,
            exchangeRouter,
            tokenUsd,
            decimalsUsd,
            averageSlippage,
            vaultStrategy
        );
        shareToken.transferOwnership(address(vault));
        getVault[msg.sender][vaultStrategy] = address(vault);
        emit VaultCreated(msg.sender, address(vault), vaultStrategy );

        return address(vault);
    }

    function setOwner(address _owner) external {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

}
