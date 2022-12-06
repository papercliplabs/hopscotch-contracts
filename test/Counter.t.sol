// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Counter.sol";

contract CounterTest is Test {
    Counter public counter;
    address acct0;
    address acct1;

    function setUp() public {
        acct0 = vm.addr(1);
        acct1 = vm.addr(2);

        vm.prank(acct0);
        counter = new Counter();
    }

    function testFailIncrementNotOwner() public {
        vm.prank(acct1);
        counter.increment();
    }

    function testIncrementOwner() public {
        vm.prank(acct0);
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function testSetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
