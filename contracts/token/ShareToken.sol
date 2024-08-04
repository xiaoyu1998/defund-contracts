// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interface.sol";
import "../utils/Printer.sol";

// @title ShareToken
// @dev Mock mintable token for testing and testnets
contract ShareToken is Ownable, ERC20 {
    uint8 private _decimals;

    constructor(        
        string memory vaultName,
        string memory vaultSymbol
    ) ERC20(vaultName, vaultSymbol) {
        _decimals = 0;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // @dev mint tokens to an account
    // @param account the account to mint to
    // @param amount the amount of tokens to mint
    function mint(address account, uint256 amount) external onlyOwner{
        _mint(account, amount);
    }

    // @dev burn tokens from an account
    // @param account the account to burn tokens for
    // @param amount the amount of tokens to burn
    function burn(address account, uint256 amount) external onlyOwner{
        _burn(account, amount);
    }

    /// @inheritdoc ERC20
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        IVault(owner()).beforeShareTransfer(from, to, amount);
    }
}
