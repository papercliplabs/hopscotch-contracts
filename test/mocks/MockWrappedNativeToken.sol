// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IWrappedNativeToken} from "../../src/IWrappedNativeToken.sol";

contract MockWrappedNativeToken is ERC20, IWrappedNativeToken {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        payable(msg.sender).call{value: amount}("");
    }
}
