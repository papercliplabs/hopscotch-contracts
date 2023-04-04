// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hopscotch.sol";

import {IWrappedNativeToken} from "../src/IWrappedNativeToken.sol";

contract HopscotchPolygonDeploy is Script {
    address public constant WMATIC_POLYGON = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Hopscotch hopscotch = new Hopscotch(WMATIC_POLYGON);

        vm.stopBroadcast();
    }
}
