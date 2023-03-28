// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Hopscotch.sol";
import {IWrappedNativeToken} from "../src/IWrappedNativeToken.sol";

contract HopscotchCreateRequestTest is Test {
    ////
    // Globals
    ////

    // Contracts under test
    IHopscotch public hopscotch;

    // Users
    address deployer;
    address creator;

    // Expected events
    event RequestCreated(
        uint256 indexed requestId,
        address indexed recipient,
        address indexed recipientToken,
        uint256 recipientTokenAmount
    );

    ////
    // Setup
    ////

    function setUp() public {
        deployer = vm.addr(1);
        creator = vm.addr(2);

        deal(deployer, 10e18);
        deal(creator, 10e18);

        vm.prank(deployer);
        hopscotch = new Hopscotch(address(0));

        vm.startPrank(creator);
    }

    ////
    // Passing tests
    ////

    function test_CreationParams() public {
        address _requestToken = address(1052);
        uint256 _requestTokenAmount = 1e8;

        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Read back the created request
        (address recipient, address recipientToken, uint256 recipientTokenAmount, bool paid) = hopscotch.getRequest(id);
        assertEq(recipient, creator);
        assertEq(recipientToken, _requestToken);
        assertEq(recipientTokenAmount, _requestTokenAmount);
        assertEq(paid, false);
    }

    function test_RequestIdIncrements() public {
        uint256 firstId = hopscotch.createRequest(address(0), 1e18);
        uint256 secondId = hopscotch.createRequest(address(0), 1e18);

        assertEq(firstId, 0);
        assertEq(secondId, 1);
    }

    function test_RequestCreatedEvent() public {
        address _requestToken = address(152);
        uint256 _requestTokenAmount = 1e18;

        // Expect this event to emit
        vm.expectEmit(true, true, true, true); // Check all indexed, and data
        emit RequestCreated(0, creator, _requestToken, _requestTokenAmount);

        hopscotch.createRequest(_requestToken, _requestTokenAmount);
    }

    ////
    // Failing tests
    ////

    function testFail_ZeroAmount() public {
        hopscotch.createRequest(address(1), 0);
    }

    ////
    // Fuzz tests
    ////

    function testFuzz_CreationParams(address _requestToken, uint256 _requestTokenAmount) public {
        vm.assume(_requestTokenAmount > 0);

        // Expect this event to emit
        vm.expectEmit(true, true, true, true); // Check all indexed, and data
        emit RequestCreated(0, creator, _requestToken, _requestTokenAmount);

        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Read back the created event
        (address recipient, address recipientToken, uint256 recipientTokenAmount, bool paid) = hopscotch.getRequest(id);
        assertEq(recipient, creator);
        assertEq(recipientToken, _requestToken);
        assertEq(recipientTokenAmount, _requestTokenAmount);
        assertEq(paid, false);
    }
}
