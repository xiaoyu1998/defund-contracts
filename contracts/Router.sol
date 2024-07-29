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
    address public immutable vaultManager;
    address public immutable exchangeRouter;
    address public immutable router;

    modifier onlyVaultManager() {
        require(msg.sender == vaultManager);
        _;
    }

    constructor(
        address _router, 
        address _exchangeRouter, 
        address _vaultManager
    ){
        router = _router;
        exchangeRouter = _exchangeRouter;
        vaultManager = _vaultManager;
    }

   //vault manager
    function executeDeposit(
        DepositParams calldata params
    ) external onlyVaultManager {
        _executeDeposit(params);
    }

    function _executeDeposit(
        DepositParams memory params
    ) internal {
        IExchangeRouter(exchangeRouter).executeDeposit(params);
    }

    function _executeBorrow(
        BorrowParams calldata params
    ) internal onlyVaultManager {
        IExchangeRouter(exchangeRouter).executeBorrow(params);
    }

    function executeRepay(
        RepayParams calldata params
    ) external onlyVaultManager {
        IExchangeRouter(exchangeRouter).executeRepay(params);
    }

    function executeRedeem(
        RedeemParams calldata params
    ) external onlyVaultManager {
        _executeRedeem(params);
    }

    function _executeRedeem(
        RedeemParams memory params
    ) internal {
        IExchangeRouter(exchangeRouter).executeRedeem(params);
    }

    function executeSwap(
        SwapParams calldata params
    ) external onlyVaultManager {
        IExchangeRouter(exchangeRouter).executeSwap(params);
    }

    function executeClosePosition(
        ClosePositionParams calldata params
    ) external onlyVaultManager {
        IExchangeRouter(exchangeRouter).executeClosePosition(params);
    }

    function executeClose(
        CloseParams calldata params
    ) external onlyVaultManager {
        IExchangeRouter(exchangeRouter).executeClose(params);
    }

    function _sendTokens(address token, address receiver, uint256 amount) internal {
        IERC20(token).approve(router, amount);
        IExchangeRouter(exchangeRouter).sendTokens(token, receiver, amount);
    }
}
