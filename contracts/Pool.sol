// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./NoDelegateCall.sol";
import "./IFundStrategy.sol";
import "./Interface.sol";
import "./utils/PayableMulticall.sol";
import "./utils/WadRayMath.sol";
import "./utils/StrictBank.sol";
import "./utils/Printer.sol";

contract Pool is NoDelegateCall, PayableMulticall, StrictBank, Printer {
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;
    address public immutable factory;
    address public immutable fundManager;
    address public immutable shareToken;

    address public immutable router;
    address public immutable exchangeRouter;
    address public immutable reader;
    address public immutable dataStore;
    address public immutable underlyingAssetUsd;
    uint256 public immutable decimalsUsd;
    address public immutable fundStrategy;

    uint256 internal unclaimFee;
    uint256 internal totalFundFee;

    mapping(address => Position) public Positions;//TODO:should update after transfer

    modifier onlyFundManager() {
        require(msg.sender == fundManager);
        _;
    }

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
        address _underlyingAssetUsd,   
        uint256 _decimalsUsd,  
        address _fundStrategy   
    ) {
        factory = _factory; 
        fundManager = _fundManager; 
        shareToken = _shareToken; 
        dataStore = _dataStore;
        reader = _reader;
        router = _router; 
        exchangeRouter = _exchangeRouter; 
        underlyingAssetUsd = _underlyingAssetUsd;
        decimalsUsd = _decimalsUsd;
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
        GetLiquidationHealthFactor memory factor
            = IReader(reader).getLiquidationHealthFactor(dataStore, address(this));
        uint256 netCollateralUsdInRay = factor.userTotalCollateralUsd - factor.userTotalDebtUsd;
        uint256 netCollateralUsd = Math.mulDiv(netCollateralUsdInRay, WadRayMath.RAY, 10**decimalsUsd);
        uint256 totalShares = IShareToken(shareToken).totalSupply();

        return (netCollateralUsd, totalShares);
    }

    //user 
    function invest() external {
        //deposit in uf
        log("-----------------------------invest-----------------------------");
        uint256 depositAmount = recordTransferIn(underlyingAssetUsd);
        address poolToken = IReader(reader).getPoolToken(dataStore, underlyingAssetUsd);
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

        IERC20(underlyingAssetUsd).approve(router, depositAmount);
        IExchangeRouter(exchangeRouter).sendTokens(underlyingAssetUsd, poolToken, depositAmount);
        DepositParams memory params = DepositParams(underlyingAssetUsd);
        _deposit(params);
    }

    function withdraw(uint256 shareAmount, address to) external {
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
        uint256 amountToWithdrawUsd = Math.mulDiv(shareAmount, netCollateralUsd, totalShares);
        uint256 sharePrice = netCollateralUsd.rayDiv(totalShares);
        // int256 profitPrice = sharePrice - Positions[msg.sender].entryPrice;

        uint256 redemptionFee = IFundStrategy(fundStrategy).redemptionFee(amountToWithdrawUsd, Positions[msg.sender].entryPrice, netCollateralUsd, totalShares);
        unclaimFee += redemptionFee;
        totalFundFee += redemptionFee;
        amountToWithdrawUsd -= redemptionFee;

        bool pending = false;
        if (IERC20(underlyingAssetUsd).balanceOf(address(this)) >= amountToWithdrawUsd) {
            transferOut(underlyingAssetUsd, to, amountToWithdrawUsd);
        } else {
            //redeem for withdraw
            address poolToken = IReader(reader).getPoolToken(dataStore, underlyingAssetUsd);
            if(IPoolToken(poolToken).balanceOfCollateral(address(this)) >= amountToWithdrawUsd) {
                RedeemParams memory params = RedeemParams(
                    underlyingAssetUsd,
                    amountToWithdrawUsd,
                    address(this)
                );
                _redeem(params);
                IERC20(underlyingAssetUsd).transfer(to, amountToWithdrawUsd);
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
    function deposit(
        DepositParams calldata params
    ) external onlyFundManager {
        _deposit(params);
    }

    function _deposit(
        DepositParams memory params
    ) internal {
        IExchangeRouter(exchangeRouter).executeDeposit(params);
    }

    function borrow(
        BorrowParams calldata params
    ) external onlyFundManager {
        GetLiquidationHealthFactor memory factor
            = IReader(reader).getLiquidationHealthFactor(dataStore, address(this));
        uint256 fundHealthThreshold = IFundStrategy(fundStrategy).healthThreshold();
        if(factor.healthFactor < fundHealthThreshold) {
            revert Errors.BelowFundHealthThrehold(factor.healthFactor, fundHealthThreshold);
        }
        IExchangeRouter(exchangeRouter).executeBorrow(params);
    }

    function repay(
        RepayParams calldata params
    ) external onlyFundManager {
        IExchangeRouter(exchangeRouter).executeRepay(params);
    }

    function redeem(
        RedeemParams calldata params
    ) external onlyFundManager {
        //IExchangeRouter(exchangeRouter).executeRedeem(params);
        _redeem(params);
    }

    function _redeem(
        RedeemParams memory params
    ) internal {
        IExchangeRouter(exchangeRouter).executeRedeem(params);
    }

    function swap(
        SwapParams calldata params
    ) external onlyFundManager {
        IExchangeRouter(exchangeRouter).executeSwap(params);
    }

    function closePosition(
        ClosePositionParams calldata params
    ) external onlyFundManager {
        IExchangeRouter(exchangeRouter).executeClosePosition(params);
    }

    function close(
        CloseParams calldata params
    ) external onlyFundManager {
        IExchangeRouter(exchangeRouter).executeClose(params);
    }

    function sendTokens(address token, address receiver, uint256 amount) external payable {
        address account = msg.sender;
        IERC20(token).safeTransferFrom(account, receiver, amount);
    }

}
