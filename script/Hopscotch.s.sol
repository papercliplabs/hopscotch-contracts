// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hopscotch.sol";

contract HopscotchScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();

        Hopscotch hopscotch = new Hopscotch();

        vm.stopBroadcast();
    }
}
