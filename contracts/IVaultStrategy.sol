// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

interface IVaultStrategy {

    function isSubscriptionPeriod() external view returns (bool);
    function firstSubscriptionFee(uint256 amount) external view returns (uint256);
    function redemptionFee(
        uint256 amountToWithdrawUsd,
        uint256 entryPrice,
        uint256 netCollateralUsd,
        uint256 totalShares
    ) external view returns (uint256);
    function healthThreshold() external view returns (uint256);

}