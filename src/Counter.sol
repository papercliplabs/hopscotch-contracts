// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract Counter is Ownable {
    uint256 public number;

    function increment() public onlyOwner {
        number++;
    }

    function setNumber(uint256 x) public {
        number = x;
    }
}
