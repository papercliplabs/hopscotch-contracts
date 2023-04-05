// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hopscotch.sol";

import {IWrappedNativeToken} from "../src/IWrappedNativeToken.sol";

contract HopscotchGoerliDeploy is Script {
    address public constant WETH_GOERLI = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Hopscotch hopscotch = new Hopscotch(WETH_GOERLI);

        vm.stopBroadcast();
    }
}
