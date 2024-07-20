// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./utils/PercentageMath.sol";
import "./utils/WadRayMath.sol";
import "./IFundStrategy.sol";
//import "../utils/Printer.sol";

contract FundStrategy is IFundStrategy {
    using PercentageMath for uint256;
    using WadRayMath for uint256;

    uint256 internal immutable _healthThreshold;
    uint256 internal immutable startTimestamp;
    uint256 internal immutable subscriptionPeriod;
    uint256 internal immutable firstSubscriptionFeeRate;
    uint256 internal immutable redemptionFeeThreshold;
    uint256 internal immutable redemptionFeeRate;

    constructor(
        uint256 healthThreshold_,
        uint256 _subscriptionPeriod,
        uint256 _firstSubscriptionFeeRate,
        uint256 _redemptionFeeThreshold,
        uint256 _redemptionFeeRate
    ) {
        startTimestamp = block.timestamp;
        subscriptionPeriod = _subscriptionPeriod;
        firstSubscriptionFeeRate = _firstSubscriptionFeeRate;
        redemptionFeeThreshold = _redemptionFeeThreshold;
        redemptionFeeRate = _redemptionFeeRate;
        _healthThreshold = healthThreshold_;
    }

    /// @inheritdoc IFundStrategy
    function healthThreshold() public view  override returns (uint256) {
        return _healthThreshold;
    }

    /// @inheritdoc IFundStrategy
    function isSubscriptionPeriod() public view  override returns (bool) {
        return block.timestamp - startTimestamp < subscriptionPeriod;
    }
    
    /// @inheritdoc IFundStrategy
    function firstSubscriptionFee(uint256 amount) public view  override returns (uint256) {
        return amount.percentMul(firstSubscriptionFeeRate);
    }

    /// @inheritdoc IFundStrategy
    function redemptionFee(
        uint256 amount,
        uint256 entryPrice,
        uint256 netCollateralUsd,
        uint256 totalShares        
    ) public view  override returns (uint256) {

        uint256 sharePrice = netCollateralUsd.rayDiv(totalShares);
        if (sharePrice - entryPrice > redemptionFeeThreshold){
            return amount.percentMul(redemptionFeeRate);
        }else{
            return 0;
        }
    }

}

