// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.24;

import './NoDelegateCall.sol';
import '../utils/PayableMulticall.sol';


contract DefundPool is NoDelegateCall, PayableMulticall {

    address public immutable factory;
    address public immutable owner;
    uint24 public immutable fee;
    uint24 public immutable healthThrehold;
    address public immutable shareToken;

    address public immutable router;
    address public immutable exchangeRouter;
    address public immutable reader;
    address public immutable dataStore;
    address public immutable underlyAssetUsd;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        (   factory,
            owner, 
            healthThrehold, 
            fee,
            shareToken,
            router,
            exchangeRouter,
            reader,
            dataStore,   
            underlyAssetUsd      
         ) = IDeployer(msg.sender).parameters();
    }

    //user 
    function invest()  {
        //deposit in uf
        uint256 depositAmount = recordTransferIn(underlyAssetUsd);
        address poolToken = IReader(reader).getPoolToken(dataStore, underlyAssetUsd);
        IERC20(underlyAssetUsd).approve(router, depositAmount);
        IExchangeRouter(exchangeRouter).sendTokens(underlyAssetUsd, poolToken, depositAmount);
        DepositParams memory params = DepositParams(underlyAssetUsd);
        deposit(params);

        //mint share token
        {   ,,,
            userTotalCollateralUsd,
            userTotalDebtUsd
        } = IReader(reader).getLiquidationHealthFactor(dataStore, address(this));
        uint256 totalValue = userTotalCollateralUsd - userTotalDebtUsd;
        uint256 totalShares = IShareToken(shareToken).totalSupply();
        uint256 sharesToMint = depositAmount*totalShares/totalValue;
        IShareToken(shareToken).mint(msg.sender, sharesToMint);
    }

    function withdraw(uint256 amount, address to) {

    }

    //fund manager
    function deposit(
        DepositParams calldata params
    ) external override onlyOwner {
       IExchangeRouter(exchangeRouter).executeDeposit(params);
    }

    function borrow(
        BorrowParams calldata params
    ) external override onlyOwner {
       IExchangeRouter(exchangeRouter).executeBorrow(params);
    }

    function repay(
        RepayParams calldata params
    ) external override onlyOwner {
       IExchangeRouter(exchangeRouter).executeRepay(params);
    }

    function redeem(
        RedeemParams calldata params
    ) external override onlyOwner {
       IExchangeRouter(exchangeRouter).executeRedeem(params);
    }

    function swap(
        SwapParams calldata params
    ) external override onlyOwner {
       IExchangeRouter(exchangeRouter).executeSwap(params);
    }

    function closePosition(
        ClosePositionParams calldata params
    ) external override onlyOwner {
       IExchangeRouter(exchangeRouter).executeClosePosition(params);
    }

    function close(
        CloseParams calldata params
    ) external override onlyOwner {
       IExchangeRouter(exchangeRouter).executeClose(params);
    }

}
