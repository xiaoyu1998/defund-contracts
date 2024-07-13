// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.24;

import './UniswapV3Pool.sol';

contract Deployer  {
    struct Parameters {
        address factory;
        address owner;
        uint24 fee;
        uint24 healthThrehold;
        address dataStore;
        address reader;
        address router;
        address exchangeRouter;
        address underlyAssetUsd;
    }

    Parameters public override parameters;

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the Df factory
    /// @param fee The fee collected upon every action in the pool, denominated in hundredths of a bip
    function deploy(
        address factory,
        address owner,
        uint24 healthFactor,
        uint24 fee,
        address dataStore,
        address reader,
        address router, 
        address exchangeRouter, 
        address underlyAssetUsd          
    ) internal returns (address pool) {
        parameters = Parameters({
            factory: factory, 
            owner: owner, 
            fee: fee,
            healthThrehold: healthThrehold, 
            dataStore: dataStore,
            reader: reader,
            router: router, 
            exchangeRouter: exchangeRouter, 
            underlyAssetUsd: underlyAssetUsd 
        });
        pool = address(new DefundPool());
        delete parameters;
    }
}
