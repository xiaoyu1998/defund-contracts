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
import "./IVaultStrategy.sol";
import "./Interface.sol";
import "./Reader.sol";
import "./Router.sol";

contract Vault is NoDelegateCall, PayableMulticall, StrictBank, Router, Reader {
    using PercentageMath for uint256;
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;
    address public immutable factory;
    address public immutable shareToken;
    address public immutable tokenUsd;
    uint256 public immutable decimalsUsd;
    uint256 public immutable averageSlippage;
    address public immutable vaultStrategy;

    uint256 public unclaimFee;
    uint256 public totalVaultFee;

    mapping(address => uint256) public entryPrices;//TODO:should update after transfer
    mapping(address => WithdrawOrder) public orders;

    uint256 internal constant ONE_DAY = 1 days;

    modifier onlyShareToken() {
        require(msg.sender == shareToken);
        _;
    }

    constructor(
        VaultConstructor memory params
    ) Router(params.router, params.exchangeRouter, params.vaultManager, params.managerName) 
      Reader(params.dataStore, params.reader)
    {
        factory = params.factory; 
        shareToken = params.shareToken; 
        tokenUsd = params.tokenUsd;
        decimalsUsd = params.decimalsUsd;
        averageSlippage = params.averageSlippage;
        vaultStrategy = params.vaultStrategy;
    }

    function _updateEntryPrice(address account, uint256 sharePrice, uint256 amount, bool isAdded) internal {
        uint256 entryPrice = entryPrices[account];
        uint256 shareAmount = IShareToken(shareToken).balanceOf(account);
        if (shareAmount == 0){
           entryPrice = sharePrice;
        } else {
            if (isAdded){
                uint256 totalValue = entryPrice.rayMul(shareAmount) +
                                     sharePrice.rayMul(amount);
                entryPrice = totalValue.rayDiv(shareAmount + amount);
            } 
        }
        entryPrices[account] = entryPrice;
    }

    function beforeShareTransfer(address from, address to, uint256 amount) external onlyShareToken {
        //mint & burn
        if (from == address(0) || to == address(0)){
            return;
        }

        //transfer
        (   uint256 netCollateralUsd,
            uint256 totalShares
        ) = _getEquity();
        uint256 sharePrice = netCollateralUsd.rayDiv(totalShares);
        uint256 shareBalance = IShareToken(shareToken).balanceOf(from);
        if (shareBalance == 0){
            revert Errors.EmptyShares(from);
        }

        if (shareBalance < amount){
            revert Errors.TransferAmountExeceedsBalance(from, shareBalance, amount);
        }
        
        _updateEntryPrice(to, sharePrice, amount, true);//add
        _updateEntryPrice(from, sharePrice, amount, false);//remove
    }

    struct GetEquityLocalVars {
        HealthFactor factor;
        uint256 netCollateralUsdInRay;
        uint256 priceTokenUsd;
        uint256 netCollateralTokenUsdInRay;
        uint256 netCollateralUsd;
        uint256 adjustNetCollateralUsd;
        uint256 totalShares;
    }

    function _getEquity() internal view returns(uint256, uint256) {
        GetEquityLocalVars memory vars;
        vars.factor = _getHealthFactor();
        vars.netCollateralUsdInRay = vars.factor.userTotalCollateralUsd - vars.factor.userTotalDebtUsd;
        vars.priceTokenUsd = _getPrice(tokenUsd);
        vars.netCollateralTokenUsdInRay = vars.netCollateralUsdInRay.rayDiv(vars.priceTokenUsd);
        vars.netCollateralUsd = Math.mulDiv(vars.netCollateralTokenUsdInRay, 10**decimalsUsd, WadRayMath.RAY);
        vars.adjustNetCollateralUsd = vars.netCollateralUsd.percentMul(10000 - averageSlippage);
        vars.totalShares = IShareToken(shareToken).totalSupply();

        return (vars.adjustNetCollateralUsd, vars.totalShares);
    }

    //investor 
    function deposit() external {
        //charge fee
        uint256 depositAmount = recordTransferIn(tokenUsd);
        address poolToken = _getPoolToken(tokenUsd);
        uint256 firstSubscriptionFee = IVaultStrategy(vaultStrategy).firstSubscriptionFee(depositAmount);
        unclaimFee += firstSubscriptionFee;
        totalVaultFee += firstSubscriptionFee;
        depositAmount -= firstSubscriptionFee;

        //update entryPrice and mint shares
        uint256 sharesToMint;
        uint256 sharePrice;
        if (IVaultStrategy(vaultStrategy).isSubscriptionPeriod()){
            sharePrice = WadRayMath.RAY;
            sharesToMint = depositAmount ;
        } else {
            (   uint256 netCollateralUsd,
                uint256 totalShares
            ) = _getEquity();
            sharesToMint = Math.mulDiv(depositAmount, totalShares, netCollateralUsd); 
            sharePrice = netCollateralUsd.rayDiv(totalShares);
        }    
        _updateEntryPrice(msg.sender, sharePrice, sharesToMint, true);
        IShareToken(shareToken).mint(msg.sender, sharesToMint);

        //deposit to up
        _sendTokens(tokenUsd, poolToken, depositAmount);
        DepositParams memory params = DepositParams(tokenUsd);
        _executeDeposit(params);
    }

    struct WithdrawLocalVars {
        uint256 shareAmountTotal;
        WithdrawOrder order;
        uint256 netCollateralUsd;
        uint256 totalShares;
        uint256 amountToWithdrawUsd;
        uint256 sharePrice;
        uint256 redemptionFee;
        uint256 balanceUsd;
        uint256 deficiencyAmount;
        address poolTokenUsd;
        RedeemParams params ;
    }

    function withdraw(uint256 shareAmountToWithdraw, address to) external {
        //Printer.log("-----------------------------withdraw-----------------------------");
        WithdrawLocalVars memory vars;
        //validate
        vars.shareAmountTotal = _validateWithdraw();
        if (shareAmountToWithdraw > vars.shareAmountTotal){
            shareAmountToWithdraw = vars.shareAmountTotal;
        }

        //update pending order
        vars.order = orders[msg.sender];
        if (vars.order.to != address(0) ){//update order
            orders[msg.sender] = WithdrawOrder(
                to,
                shareAmountToWithdraw,
                block.timestamp,
                true
            ); 
            return;            
        }

        //charge fee
        (   vars.netCollateralUsd,
            vars.totalShares
        ) = _getEquity();
        vars.amountToWithdrawUsd = Math.mulDiv(shareAmountToWithdraw, vars.netCollateralUsd, vars.totalShares);
        vars.sharePrice = vars.netCollateralUsd.rayDiv(vars.totalShares);
        vars.redemptionFee = IVaultStrategy(vaultStrategy).redemptionFee(
            vars.amountToWithdrawUsd, 
            entryPrices[msg.sender], 
            vars.netCollateralUsd, 
            vars.totalShares
        );
        unclaimFee += vars.redemptionFee;
        totalVaultFee += vars.redemptionFee;
        vars.amountToWithdrawUsd -= vars.redemptionFee;

        //withdraw or redeem collateral withdraw
        vars.balanceUsd = IERC20(tokenUsd).balanceOf(address(this));
        if (vars.balanceUsd >= vars.amountToWithdrawUsd) {
            vars.deficiencyAmount = vars.amountToWithdrawUsd - vars.balanceUsd;
            vars.poolTokenUsd = _getPoolToken(tokenUsd);
            if (IPoolToken(vars.poolTokenUsd).balanceOfCollateral(address(this)) < vars.deficiencyAmount) {
                //pending for a day
                orders[msg.sender] = WithdrawOrder(
                    to,
                    vars.amountToWithdrawUsd,
                    block.timestamp,
                    true
                );
                return;
            } else {
                vars.params = RedeemParams(
                    tokenUsd,
                    vars.deficiencyAmount,
                    address(this)
                );
                _executeRedeem(vars.params);
            }
        }
        
        //mint share token
        transferOut(tokenUsd, to, vars.amountToWithdrawUsd);
        _updateEntryPrice(msg.sender, vars.sharePrice, shareAmountToWithdraw, false);
        IShareToken(shareToken).burn(msg.sender, shareAmountToWithdraw);
    }

    function _validateWithdraw() internal view returns (uint256){
        if (IVaultStrategy(vaultStrategy).isSubscriptionPeriod()){
            revert Errors.SubscriptionPeriodCanNotWithdraw();
        }

        uint256 shareAmountTotal = IShareToken(shareToken).balanceOf(msg.sender);
        if (shareAmountTotal == 0){
            revert Errors.EmptyShares(msg.sender);
        }  

        return shareAmountTotal;
    }

    struct ExecuteWithdrawOrderLocalVars {
        WithdrawOrder order;
        uint256 balanceUsd;
        uint256 amountToWithdrawUsd;
        uint256 deficiencyAmount;
        address poolTokenUsd;
        SwapParams swapParams;
        RedeemParams redeemParams;
    }

    function executeWithdrawOrder(address tokenToSell) external {
        ExecuteWithdrawOrderLocalVars memory vars;
        vars.order = orders[msg.sender];
        _validateExecuteWithdrawOrder(vars.order, msg.sender);

        vars.balanceUsd = IERC20(tokenUsd).balanceOf(address(this));
        vars.amountToWithdrawUsd = vars.order.amountToWithdrawUsd;
        if (vars.balanceUsd < vars.amountToWithdrawUsd) {
            vars.deficiencyAmount = vars.amountToWithdrawUsd - vars.balanceUsd;
            vars.poolTokenUsd = _getPoolToken(tokenUsd);
            if (IPoolToken(vars.poolTokenUsd).balanceOfCollateral(address(this)) < vars.deficiencyAmount) {
                vars.swapParams = SwapParams(
                    tokenToSell,
                    tokenUsd,
                    vars.deficiencyAmount,
                    0
                );
                _executeSwapExactOut(vars.swapParams);
            }

            vars.redeemParams = RedeemParams(
                tokenUsd,
                vars.deficiencyAmount,
                address(this)
            );
            _executeRedeem(vars.redeemParams);
        }

        transferOut(tokenUsd, vars.order.to, vars.amountToWithdrawUsd);
        vars.order.isOpen = false;
        orders[msg.sender] = vars.order;

    }

    function _validateExecuteWithdrawOrder(WithdrawOrder memory order, address account) internal view {
        if (!order.isOpen){
            revert Errors.WithdrawOrderClosed(account);
        }
        if (order.to == address(0) ){//update order
            revert Errors.EmptyWithdrawOrder(account);
        }

        if (block.timestamp - order.submitTime < ONE_DAY){
            revert Errors.LessThanOneDay();
        }
    }

    function sendTokens(address token, address receiver, uint256 amount) external payable {
        address account = msg.sender;
        IERC20(token).safeTransferFrom(account, receiver, amount);
    }

    //vault manager
    function executeBorrow(
        BorrowParams calldata params
    ) external onlyVaultManager {
        _validateBorrow(params);
        _executeBorrow(params);
    }

    //validate
    function _validateBorrow(
        BorrowParams memory params
    ) internal view {
        // Printer.log("-----------------------------_validateBorrow-----------------------------");
        HealthFactor memory factor = _getHealthFactor();
        GetPoolPrice memory poolPrice = _getPoolPrice(params.underlyingAsset);
        uint256 adjustAmount = Math.mulDiv(params.amount, WadRayMath.RAY, 10**poolPrice.decimals);//align to Ray
        uint256 amountUsd = poolPrice.price.rayMul(adjustAmount);
        uint256 healthFactor = 
            (factor.userTotalCollateralUsd + amountUsd).rayDiv(factor.userTotalDebtUsd + amountUsd);
 
        uint256 vaultHealthThreshold = IVaultStrategy(vaultStrategy).healthThreshold();
        if (healthFactor < vaultHealthThreshold) {
            revert Errors.BelowVaultHealthThrehold(healthFactor, vaultHealthThreshold);
        }       
    }

}
