// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hopscotch.sol";

import {IWrappedNativeToken} from "../src/IWrappedNativeToken.sol";

contract HopscotchGoerliDeploy is Script {
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Hopscotch hopscotch = new Hopscotch(WETH);

        vm.stopBroadcast();
    }
}
