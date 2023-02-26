// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hopscotch.sol";

import {IWrappedNativeToken} from "../src/IWrappedNativeToken.sol";

contract HopscotchScript is Script {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Hopscotch hopscotch = new Hopscotch(WETH);

        vm.stopBroadcast();
    }
}
