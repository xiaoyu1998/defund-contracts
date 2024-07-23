// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Interface.sol";
/**
 * @title Router
 * @dev Users will approve this router for token spenditures
 */
contract Router {
    using SafeERC20 for IERC20;
    address public immutable fundManager;
    address public immutable exchangeRouter;
    address public immutable router;

    modifier onlyFundManager() {
        require(msg.sender == fundManager);
        _;
    }

    constructor(
        address _router, 
        address _exchangeRouter, 
        address _fundManager
    ){
        router = _router;
        exchangeRouter = _exchangeRouter;
        fundManager = _fundManager;
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

    function _borrow(
        BorrowParams calldata params
    ) internal onlyFundManager {
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

    function _sendTokens(address token, address receiver, uint256 amount) internal {
        IERC20(token).approve(router, amount);
        IExchangeRouter(exchangeRouter).sendTokens(token, receiver, amount);
    }
}
