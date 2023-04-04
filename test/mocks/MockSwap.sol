// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

contract MockSwap {
    using SafeERC20 for IERC20;

    // Dummy swap function, assumes the contract has enough output tokens to perform the swap
    function swap(address inputToken, uint256 inputTokenAmount, address outputToken, uint256 outputTokenAmount)
        external
    {
        require(IERC20(inputToken).allowance(msg.sender, address(this)) >= inputTokenAmount, "not enough allowance");
        require(
            IERC20(outputToken).balanceOf(address(this)) >= outputTokenAmount,
            "not enough output tokens to perform swap"
        );

        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), inputTokenAmount);
        IERC20(outputToken).safeTransfer(msg.sender, outputTokenAmount);
    }
}
