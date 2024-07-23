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
    //address public immutable fundManager;
    address public immutable shareToken;

    // address public immutable router;
    // address public immutable exchangeRouter;
    address public immutable tokenUsd;
    uint256 public immutable decimalsUsd;
    uint256 public immutable averageSlippage;
    address public immutable fundStrategy;

    uint256 internal unclaimFee;
    uint256 internal totalFundFee;

    mapping(address => Position) public Positions;//TODO:should update after transfer

    // modifier onlyFundManager() {
    //     require(msg.sender == fundManager);
    //     _;
    // }

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

    function updatePositionForShareTransfer(address from, address to, uint256 amount) external onlyShareToken {
        Position memory positionFrom = Positions[from];
        if(positionFrom.entryPrice == 0){
            revert Errors.EmptyShares(from);
        }
        (   uint256 netCollateralUsd,
            uint256 totalShares
        ) = getEquity();
        uint256 sharePrice = netCollateralUsd.rayDiv(totalShares);

        updatePosition(from, sharePrice, amount, false);//withdraw
        updatePosition(to, sharePrice, amount, true);//invest
    }

    function updatePosition(address account, uint256 sharePrice, uint256 amount, bool isInvest) internal {
        Position memory position = Positions[account];
        if(position.entryPrice == 0){
           position.entryPrice = sharePrice;
           position.accAmount = amount;
        } else {
            if (isInvest){
                uint256 totalValue = position.entryPrice.rayMul(position.accAmount) +
                                     sharePrice.rayMul(amount);
                position.accAmount += amount;
                position.entryPrice = totalValue.rayDiv(position.accAmount);
            } else {
                position.accAmount -= amount;
            }
        }
        Positions[account] = position;
    }

    function getEquity() internal returns(uint256, uint256) {
        GetLiquidationHealthFactor memory factor = _getLiquidationHealthFactor();
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
        //deposit in uf
        log("-----------------------------invest-----------------------------");
        uint256 depositAmount = recordTransferIn(tokenUsd);
        address poolToken = _getPoolToken(tokenUsd);
        uint256 firstSubscriptionFee = IFundStrategy(fundStrategy).firstSubscriptionFee(depositAmount);
        unclaimFee += firstSubscriptionFee;
        totalFundFee += firstSubscriptionFee;
        depositAmount -= firstSubscriptionFee;

        log("unclaimFee", unclaimFee);
        log("totalFundFee", totalFundFee);
        log("depositAmount", depositAmount);

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
        updatePosition(msg.sender, sharePrice, sharesToMint, true);
        IShareToken(shareToken).mint(msg.sender, sharesToMint);

        //IERC20(tokenUsd).approve(router, depositAmount);
        //IExchangeRouter(exchangeRouter).sendTokens(tokenUsd, poolToken, depositAmount);
        _sendTokens(tokenUsd, poolToken, depositAmount);
        DepositParams memory params = DepositParams(tokenUsd);
        _deposit(params);
    }

    function withdraw(uint256 shareAmount, address to) external {
        log("-----------------------------withdraw-----------------------------");
        log("shareAmount", shareAmount);
        log("to", to);
        //validate pending
        if (IFundStrategy(fundStrategy).isSubscriptionPeriod()){
            revert Errors.SubscriptionPeriodCanNotWithdraw();
        }

        Position memory position = Positions[msg.sender];
        if(position.entryPrice == 0){
            revert Errors.EmptyShares(msg.sender);
        }

        //withdraw or redeem collateral withdraw
        (   uint256 netCollateralUsd,
            uint256 totalShares
        ) = getEquity();
        log("netCollateralUsd", netCollateralUsd);
        log("totalShares", totalShares);
        uint256 amountToWithdrawUsd = Math.mulDiv(shareAmount, netCollateralUsd, totalShares);
        uint256 sharePrice = netCollateralUsd.rayDiv(totalShares);
        log("amountToWithdrawUsd", amountToWithdrawUsd);
        log("sharePrice", sharePrice);

        uint256 redemptionFee = IFundStrategy(fundStrategy).redemptionFee(amountToWithdrawUsd, Positions[msg.sender].entryPrice, netCollateralUsd, totalShares);
        unclaimFee += redemptionFee;
        totalFundFee += redemptionFee;
        amountToWithdrawUsd -= redemptionFee;

        log("unclaimFee", unclaimFee);
        log("totalFundFee", totalFundFee);
        log("amountToWithdrawUsd", amountToWithdrawUsd);

        bool pending = false;
        if (IERC20(tokenUsd).balanceOf(address(this)) >= amountToWithdrawUsd) {
            transferOut(tokenUsd, to, amountToWithdrawUsd);
        } else {
            //redeem for withdraw
            address poolToken = _getPoolToken(tokenUsd);
            if(IPoolToken(poolToken).balanceOfCollateral(address(this)) >= amountToWithdrawUsd) {
                RedeemParams memory params = RedeemParams(
                    tokenUsd,
                    amountToWithdrawUsd,
                    address(this)
                );
                _redeem(params);
                //IERC20(tokenUsd).transfer(to, amountToWithdrawUsd);
                transferOut(tokenUsd, to, amountToWithdrawUsd);
            } else {
                //pending for 1 day
                pending = true;
            }
        }
        
        //mint share token
        if (!pending) {
            updatePosition(msg.sender, sharePrice, shareAmount,false);
            IShareToken(shareToken).burn(msg.sender, shareAmount);
        }
    }

    //fund manager
    function borrow(
        BorrowParams calldata params
    ) external onlyFundManager {
        GetLiquidationHealthFactor memory factor = _getLiquidationHealthFactor();
        uint256 fundHealthThreshold = IFundStrategy(fundStrategy).healthThreshold();
        if(factor.healthFactor < fundHealthThreshold) {
            revert Errors.BelowFundHealthThrehold(factor.healthFactor, fundHealthThreshold);
        }

        _borrow(params);
    }


    function sendTokens(address token, address receiver, uint256 amount) external payable {
        address account = msg.sender;
        IERC20(token).safeTransferFrom(account, receiver, amount);
    }

}
