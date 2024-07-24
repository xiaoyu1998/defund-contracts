// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

struct DepositParams {
    address underlyingAsset;
}

struct BorrowParams {
    address underlyingAsset;
    uint256 amount;
}

struct RepayParams {
    address underlyingAsset;
    uint256 amount;
}

struct RedeemParams {
    address underlyingAsset;
    uint256 amount;
    address to;
}

struct SwapParams {
    address underlyingAssetIn;
    address underlyingAssetOut;
    uint256 amount;
    uint256 sqrtPriceLimitX96;
}

struct ClosePositionParams {
    address underlyingAsset;
    address underlyingAssetUsd;
}

struct CloseParams {
    address underlyingAssetUsd;
}

interface IExchangeRouter {
    function sendTokens(
        address token, 
        address receiver, 
        uint256 amount
    ) external;

    function executeDeposit(
        DepositParams calldata params
    ) external payable;

    function executeBorrow(
        BorrowParams calldata params
    ) external payable;

    function executeRepay(
        RepayParams calldata params
    ) external payable;

    function executeRedeem(
        RedeemParams calldata params
    ) external payable;

    function executeSwap(
        SwapParams calldata params
    ) external payable;

    function executeClosePosition(
        ClosePositionParams calldata params
    ) external payable;

    function executeClose(
        CloseParams calldata params
    ) external payable;
    
}

struct Position {
    uint256 entryPrice;
    uint256 accAmount;
}

struct GetLiquidationHealthFactor {
    uint256 healthFactor;
    uint256 healthFactorLiquidationThreshold;
    bool isHealthFactorHigherThanLiquidationThreshold;
    uint256 userTotalCollateralUsd;
    uint256 userTotalDebtUsd;
}

struct GetMarginAndSupply {
    address underlyingAsset;
    address account;
    uint256 balanceAsset;
    uint256 debt; 
    uint256 borrowApy;
    uint256 maxWithdrawAmount;
    uint256 balanceSupply;
    uint256 supplyApy;
}

struct GetPositionInfo {
    address account;
    address underlyingAsset;
    uint256 positionType;
    int256 equity;
    int256 equityUsd;
    uint256 indexPrice;
    uint256 entryPrice;
    int256 pnlUsd; 
    uint256 liquidationPrice;
    uint256 presentageToLiquidationPrice;
}

interface IReader { 
    function getLiquidationHealthFactor(
        address dataStore, 
        address account
    ) external view returns (GetLiquidationHealthFactor memory);

    function getPositionsInfo(
        address dataStore, 
        address account
    ) external view returns (GetPositionInfo[] memory);

    function getMarginsAndSupplies(
        address dataStore, 
        address account
    ) external view returns (GetMarginAndSupply[] memory);

    function getPoolToken(
        address dataStore, 
        address underlyingAsset
    ) external view returns (address);

    function getPrice(
        address dataStore, 
        address underlyingAsset
    ) external view returns (uint256);
}

interface IShareToken {
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
    function totalSupply() external view returns(uint256);
    function balanceOf(address account) external view returns(uint256);
}


interface IPoolToken {
    function balanceOfCollateral (address account) external view returns (uint256);
}

interface IPool {
    function updatePositionForShareTransfer (address from, address to, uint256 amount) external;
}