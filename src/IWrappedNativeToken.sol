// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IWrappedNativeToken is IERC20 {
    /// @notice Deposit native asset to get wrapped native token
    function deposit() external payable;

    /// @notice Withdraw wrapped native asset to get native asset
    function withdraw(uint256 amount) external;
}
