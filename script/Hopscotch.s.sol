// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hopscotch.sol";

import {IWrappedNativeToken} from "../src/IWrappedNativeToken.sol";

contract HopscotchScript is Script {
    IWrappedNativeToken public constant WETH9 =
        IWrappedNativeToken(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {}

    function run() public {
        vm.broadcast();

        Hopscotch hopscotch = new Hopscotch(WETH9);

        vm.stopBroadcast();
    }
}
