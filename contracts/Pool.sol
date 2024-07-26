// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./utils/PayableMulticall.sol";
import "./utils/WadRayMath.sol";
import "./utils/StrictBank.sol";
import "./utils/Printer.sol";
import "./utils/PercentageMath.sol";
import "./NoDelegateCall.sol";
import "./IFundStrategy.sol";
import "./Interface.sol";
import "./Reader.sol";
import "./Router.sol";

contract Pool is NoDelegateCall, PayableMulticall, StrictBank, Router, Reader, Printer {
    using PercentageMath for uint256;
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;
    address public immutable factory;
    address public immutable shareToken;
    address public immutable tokenUsd;
    uint256 public immutable decimalsUsd;
    uint256 public immutable averageSlippage;
    address public immutable fundStrategy;

    uint256 public unclaimFee;
    uint256 public totalFundFee;

    mapping(address => uint256) public entryPrices;//TODO:should update after transfer

    modifier onlyShareToken() {
        require(msg.sender == shareToken);
        _;
    }

    constructor(
        address _factory,
        address _fundManager,
        address _shareToken,
        address _dataStore,
        address _reader,
        address _router, 
        address _exchangeRouter, 
        address _tokenUsd,   
        uint256 _decimalsUsd,  
        uint256 _averageSlippage, 
        address _fundStrategy   
    ) Router(_router, _exchangeRouter, _fundManager) 
      Reader(_dataStore, _reader)
    {
        factory = _factory; 
        shareToken = _shareToken; 
        tokenUsd = _tokenUsd;
        decimalsUsd = _decimalsUsd;
        averageSlippage = _averageSlippage;
        fundStrategy = _fundStrategy;
    }

    function updateEntryPrice(address account, uint256 sharePrice, uint256 amount, bool isInvest) internal {
        uint256 entryPrice = entryPrices[account];
        uint256 shareAmount = IShareToken(shareToken).balanceOf(account);
        if (shareAmount == 0){
           entryPrice = sharePrice;
        } else {
            if (isInvest){
                uint256 totalValue = entryPrice.rayMul(shareAmount) +
                                     sharePrice.rayMul(amount);
                entryPrice = totalValue.rayDiv(shareAmount + amount);
            } 
        }
        entryPrices[account] = entryPrice;
    }

    function beforeShareTransfer(address from, address to, uint256 amount) external onlyShareToken {
        //Position memory positionFrom = Positions[from];
        uint256 shareAmountFrom = IShareToken(shareToken).balanceOf(from);
        if (shareAmountFrom == 0){
            revert Errors.EmptyShares(from);
        }
        (   uint256 netCollateralUsd,
            uint256 totalShares
        ) = getEquity();
        uint256 sharePrice = netCollateralUsd.rayDiv(totalShares);

        updateEntryPrice(from, sharePrice, amount, false);//withdraw
        updateEntryPrice(to, sharePrice, amount, true);//invest
    }

    function getEquity() internal view returns(uint256, uint256) {
        HealthFactor memory factor = _getHealthFactor();
        uint256 netCollateralUsdInRay = factor.userTotalCollateralUsd - factor.userTotalDebtUsd;
        uint256 priceTokenUsd = _getPrice(tokenUsd);
        uint256 netCollateralTokenUsdInRay = netCollateralUsdInRay.rayDiv(priceTokenUsd);
        uint256 netCollateralUsd = Math.mulDiv(netCollateralTokenUsdInRay, 10**decimalsUsd, WadRayMath.RAY);
        uint256 adjustNetCollateralUsd = netCollateralUsd.percentMul(10000 - averageSlippage);
        uint256 totalShares = IShareToken(shareToken).totalSupply();

        return (adjustNetCollateralUsd, totalShares);
    }

    //user 
    function invest() external {
        log("-----------------------------invest-----------------------------");
        //charge fee
        uint256 depositAmount = recordTransferIn(tokenUsd);
        address poolToken = _getPoolToken(tokenUsd);
        uint256 firstSubscriptionFee = IFundStrategy(fundStrategy).firstSubscriptionFee(depositAmount);
        unclaimFee += firstSubscriptionFee;
        totalFundFee += firstSubscriptionFee;
        depositAmount -= firstSubscriptionFee;

        log("unclaimFee", unclaimFee);
        log("totalFundFee", totalFundFee);
        log("depositAmount", depositAmount);

        //update entryPrice and mint shares
        uint256 sharesToMint;
        uint256 sharePrice;
        if (IFundStrategy(fundStrategy).isSubscriptionPeriod()){
            sharePrice = WadRayMath.RAY;
            sharesToMint = depositAmount ;
        } else {
            (   uint256 netCollateralUsd,
                uint256 totalShares
            ) = getEquity();
            sharesToMint = Math.mulDiv(depositAmount, totalShares, netCollateralUsd); 
            sharePrice = netCollateralUsd.rayDiv(totalShares);
        }
        log("sharesToMint", sharesToMint);
        log("sharePrice", sharePrice);      
        updateEntryPrice(msg.sender, sharePrice, sharesToMint, true);
        IShareToken(shareToken).mint(msg.sender, sharesToMint);

        //deposit in up
        _sendTokens(tokenUsd, poolToken, depositAmount);
        DepositParams memory params = DepositParams(tokenUsd);
        _deposit(params);
    }

    function withdraw(uint256 shareAmountToWithdraw, address to) external {
        log("-----------------------------withdraw-----------------------------");
        //validate pending

        //validate
        uint256 shareAmountTotal = _validateWithdraw();
        if (shareAmountToWithdraw > shareAmountTotal){
            shareAmountToWithdraw = shareAmountTotal;
        }

        //charge fee
        (   uint256 netCollateralUsd,
            uint256 totalShares
        ) = getEquity();
        uint256 amountToWithdrawUsd = Math.mulDiv(shareAmountToWithdraw, netCollateralUsd, totalShares);
        uint256 sharePrice = netCollateralUsd.rayDiv(totalShares);
        uint256 redemptionFee = IFundStrategy(fundStrategy).redemptionFee(
            amountToWithdrawUsd, 
            entryPrices[msg.sender], 
            netCollateralUsd, 
            totalShares
        );
        unclaimFee += redemptionFee;
        totalFundFee += redemptionFee;
        amountToWithdrawUsd -= redemptionFee;

        //withdraw or redeem collateral withdraw
        bool pending = false;
        if (IERC20(tokenUsd).balanceOf(address(this)) >= amountToWithdrawUsd) {
            transferOut(tokenUsd, to, amountToWithdrawUsd);
        } else {
            //redeem from up
            address poolToken = _getPoolToken(tokenUsd);
            if (IPoolToken(poolToken).balanceOfCollateral(address(this)) >= amountToWithdrawUsd) {
                RedeemParams memory params = RedeemParams(
                    tokenUsd,
                    amountToWithdrawUsd,
                    address(this)
                );
                _redeem(params);
                transferOut(tokenUsd, to, amountToWithdrawUsd);
            } else {
                //pending for 1 day
                pending = true;
            }
        }
        
        //mint share token
        if (!pending) {
            updateEntryPrice(msg.sender, sharePrice, shareAmountToWithdraw, false);
            IShareToken(shareToken).burn(msg.sender, shareAmountToWithdraw);
        }
    }

    function _validateWithdraw() internal view returns (uint256){
        if (IFundStrategy(fundStrategy).isSubscriptionPeriod()){
            revert Errors.SubscriptionPeriodCanNotWithdraw();
        }

        uint256 shareAmountTotal = IShareToken(shareToken).balanceOf(msg.sender);
        if (shareAmountTotal == 0){
            revert Errors.EmptyShares(msg.sender);
        }  

        return shareAmountTotal;
    }

    //fund manager
    function borrow(
        BorrowParams calldata params
    ) external onlyFundManager {
        _validateBorrow(params);
        _borrow(params);
    }

    function sendTokens(address token, address receiver, uint256 amount) external payable {
        address account = msg.sender;
        IERC20(token).safeTransferFrom(account, receiver, amount);
    }

    //validate
    function _validateBorrow(
        BorrowParams memory params
    ) internal view {
        log("-----------------------------_validateBorrow-----------------------------");
        HealthFactor memory factor = _getHealthFactor();
        console.log("healthFactor", factor.healthFactor);   
        console.log("healthFactorLiquidationThreshold", factor.healthFactorLiquidationThreshold);   
        console.log("userTotalCollateralUsd", factor.userTotalCollateralUsd);   
        console.log("userTotalDebtUsd", factor.userTotalDebtUsd);  

        GetPoolPrice memory poolPrice = _getPoolPrice(params.underlyingAsset);
        console.log("underlyingAsset", poolPrice.underlyingAsset);
        console.log("symbol", poolPrice.symbol);
        console.log("price", poolPrice.price);
        console.log("decimals", poolPrice.decimals);
        console.log("amount", params.amount);

        uint256 adjustAmount = Math.mulDiv(params.amount, WadRayMath.RAY, 10**poolPrice.decimals);//align to Ray
        console.log("adjustAmount", adjustAmount); 
        uint256 amountUsd = poolPrice.price.rayMul(adjustAmount);
        console.log("amountUsd", amountUsd); 
        uint256 healthFactor = 
            (factor.userTotalCollateralUsd + amountUsd).rayDiv(factor.userTotalDebtUsd + amountUsd);

        // console.log("adjustAmount", adjustAmount);   
        // console.log("amountUsd", amountUsd);   
        console.log("healthFactor", healthFactor);   

        uint256 fundHealthThreshold = IFundStrategy(fundStrategy).healthThreshold();
        if (healthFactor < fundHealthThreshold) {
            revert Errors.BelowFundHealthThrehold(healthFactor, fundHealthThreshold);
        }       
    }

}
