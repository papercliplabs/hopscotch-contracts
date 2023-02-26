// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Hopscotch.sol";
import {IWrappedNativeToken} from "../src/IWrappedNativeToken.sol";

import {ISwapRouter} from "uniswap-v3-periphery/interfaces/ISwapRouter.sol";

contract HopscotchTest is Test {
    // RPC's
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    // Forks
    uint256 mainnetFork;

    // Fork block numbers
    uint256 mainnetBlockNumber = 16457587;

    // Tokens
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Users
    address alice;
    address bob;
    address matt;

    // External contracts
    address public constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    // Contracts under test
    IHopscotch public hopscotch;

    // Constants
    uint256 public constant ERC20_MINT_AMMOUNT = 1e25;

    // Expected events
    event RequestCreated(
        uint256 indexed requestId,
        address indexed recipient,
        address indexed recipientToken,
        uint256 recipientTokenAmount
    );

    // Helpers
    function selectMainnetFork() public {
        vm.selectFork(mainnetFork);
        vm.rollFork(mainnetBlockNumber);
    }

    // Setup
    function setUp() public {
        // Create forks
        mainnetFork = vm.createFork(MAINNET_RPC_URL);

        selectMainnetFork();

        // Assign users
        alice = vm.addr(1);
        bob = vm.addr(2);
        matt = vm.addr(3);

        // Deploy contracts (alice is owner)
        vm.prank(alice);
        hopscotch = new Hopscotch(WETH);

        // Mint initial ERC20's, matt is broke
        deal(DAI, alice, ERC20_MINT_AMMOUNT);
        deal(DAI, bob, ERC20_MINT_AMMOUNT);

        deal(USDC, alice, ERC20_MINT_AMMOUNT);
        deal(USDC, bob, ERC20_MINT_AMMOUNT);

        deal(WETH, alice, ERC20_MINT_AMMOUNT);
        deal(WETH, bob, ERC20_MINT_AMMOUNT);

        deal(alice, ERC20_MINT_AMMOUNT);
        deal(bob, ERC20_MINT_AMMOUNT);
    }

    // Setup Tests
    function testCanSelectFork() public {
        selectMainnetFork();

        assertEq(vm.activeFork(), mainnetFork);
        assertEq(block.number, mainnetBlockNumber);
    }

    function testDealErc20() public {
        assertEq(IERC20(DAI).balanceOf(address(alice)), ERC20_MINT_AMMOUNT);
        assertEq(IERC20(DAI).balanceOf(address(bob)), ERC20_MINT_AMMOUNT);
        assertEq(IERC20(DAI).balanceOf(address(matt)), 0);

        assertEq(IERC20(USDC).balanceOf(address(alice)), ERC20_MINT_AMMOUNT);
        assertEq(IERC20(USDC).balanceOf(address(bob)), ERC20_MINT_AMMOUNT);
        assertEq(IERC20(USDC).balanceOf(address(matt)), 0);
    }

    // Contract tests
    function testCreateRequest(address requestToken, uint256 requestAmount) public {
        vm.assume(requestAmount > 0);

        // Expect this event to emit
        vm.expectEmit(true, true, true, true); // Check all indexed, and data
        emit RequestCreated(0, alice, requestToken, requestAmount);

        vm.prank(alice);
        uint256 id = hopscotch.createRequest(requestToken, requestAmount);

        // Read back the created event
        (address recipient, address recipientToken, uint256 recipientTokenAmount, bool paid) = hopscotch.getRequest(id);
        assertEq(recipient, alice);
        assertEq(recipientToken, requestToken);
        assertEq(recipientTokenAmount, requestAmount);
        assertEq(paid, false);

        // Verify id incremented by 1 on next creation
        vm.expectEmit(true, true, true, true); // Check all indexed, and data
        emit RequestCreated(1, matt, USDC, requestAmount);
        vm.prank(matt);
        uint256 nextId = hopscotch.createRequest(USDC, requestAmount);

        assertEq(nextId, 1);
    }

    function testCreateRequestZeroAmount() public {
        vm.prank(bob);

        vm.expectRevert();
        hopscotch.createRequest(DAI, 0);
    }

    function testPayNativeRequestDirectly() public {
        address requestToken = address(0);
        uint256 requestAmount = 10000000;

        // Alice create the request
        vm.prank(alice);
        uint256 id = hopscotch.createRequest(requestToken, requestAmount);

        // Bob is going to pay it
        vm.startPrank(bob);

        // Capture unpaid request balances
        uint256 aliceRequestTokenBalanceBefore = alice.balance;

        // Bob pays the request, don't need swap
        hopscotch.payRequest{value: requestAmount}(IHopscotch.PayRequestInputParams(id, address(requestToken), requestAmount, address(0), ""));

        // Make sure the request has been paid
        (,,,bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        uint256 recipientRequestTokenIncreace = alice.balance - aliceRequestTokenBalanceBefore;

        assertEq(recipientRequestTokenIncreace, requestAmount);
    }

    function testPayErc20RequestDirectly() public {
        address requestToken = DAI;
        uint256 requestAmount = 10000000;

        // Alice create the request
        vm.prank(alice);
        uint256 id = hopscotch.createRequest(requestToken, requestAmount);

        // Bob is going to pay it
        vm.startPrank(bob);

        // Capture unpaid request balances
        uint256 aliceRequestTokenBalanceBefore = IERC20(requestToken).balanceOf(alice);

        // Approve input amount
        IERC20(requestToken).approve(address(hopscotch), requestAmount);

        // Bob pays the request, don't need swap
        hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, address(requestToken), requestAmount, address(0), ""));

        // Make sure the request has been paid
        (,,,bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        uint256 recipientRequestTokenIncreace = IERC20(requestToken).balanceOf(alice) - aliceRequestTokenBalanceBefore;

        assertEq(recipientRequestTokenIncreace, requestAmount);
    }

    function testPayNativeRequestWithWrappedNative() public {
        address requestToken = address(0);
        uint256 requestAmount = 10000000;

        // Alice create the request
        vm.prank(alice);
        uint256 id = hopscotch.createRequest(requestToken, requestAmount);

        // Bob is going to pay it
        vm.startPrank(bob);

        // Capture unpaid request balances
        uint256 aliceRequestTokenBalanceBefore = alice.balance;

        // Approve input amount
        IERC20(WETH).approve(address(hopscotch), requestAmount);

        // Bob pays the request, don't need swap
        hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, WETH, requestAmount, address(0), ""));

        // Make sure the request has been paid
        (,,,bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        uint256 recipientRequestTokenIncreace = alice.balance - aliceRequestTokenBalanceBefore;

        assertEq(recipientRequestTokenIncreace, requestAmount);
    }

    function testPayWrappedNativeRequestWithNative() public {
        address requestToken = WETH;
        uint256 requestAmount = 10000000;

        // Alice create the request
        vm.prank(alice);
        uint256 id = hopscotch.createRequest(requestToken, requestAmount);

        // Bob is going to pay it
        vm.startPrank(bob);

        // Capture unpaid request balances
        uint256 aliceRequestTokenBalanceBefore = IERC20(requestToken).balanceOf(alice);

        // Bob pays the request, don't need swap
        hopscotch.payRequest{value: requestAmount}(IHopscotch.PayRequestInputParams(id, address(0), requestAmount, address(0), ""));

        // Make sure the request has been paid
        (,,,bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        uint256 recipientRequestTokenIncreace = IERC20(requestToken).balanceOf(alice) - aliceRequestTokenBalanceBefore;

        assertEq(recipientRequestTokenIncreace, requestAmount);
    }

    function testPayErc20RequestWithErc20UniswapSwap() public {
        address requestToken = DAI;
        uint256 requestAmount = 10000000;

        address payToken = USDC;
        uint256 payTokenAmount = 1000000000;

        // Alice create the request
        vm.prank(alice);
        uint256 id = hopscotch.createRequest(requestToken, requestAmount);

        // Bob is going to pay it
        vm.startPrank(bob);

        // Capture unpaid request balances
        uint256 aliceRequestTokenBalanceBefore = IERC20(requestToken).balanceOf(alice);

        // Approve input amount
        IERC20(payToken).approve(address(hopscotch), payTokenAmount);

        // Get uniswap call data
        bytes memory swapCallData = abi.encodeWithSelector(
            ISwapRouter.exactOutputSingle.selector,
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(payToken),
                tokenOut: address(requestToken),
                fee: 500,
                recipient: address(hopscotch),
                deadline: block.timestamp,
                amountOut: requestAmount,
                amountInMaximum: payTokenAmount,
                sqrtPriceLimitX96: 0
            })
        );

        // Bob pays the request with Uniswap 
        hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, address(payToken), payTokenAmount, UNISWAP_V3_ROUTER, swapCallData));

        // Make sure the request has been paid
        (,,,bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        uint256 recipientRequestTokenIncreace = IERC20(requestToken).balanceOf(alice) - aliceRequestTokenBalanceBefore;

        assertEq(recipientRequestTokenIncreace, requestAmount);
    }

    function testPayNativeRequestWithErc20UniswapSwap() public {
        address requestToken = address(0);
        uint256 requestAmount = 10000000;

        address payToken = USDC;
        uint256 payTokenAmount = 1000000000;

        // Alice create the request
        vm.prank(alice);
        uint256 id = hopscotch.createRequest(requestToken, requestAmount);

        // Bob is going to pay it
        vm.startPrank(bob);

        // Capture unpaid request balances
        uint256 aliceRequestTokenBalanceBefore = alice.balance;

        // Approve input amount
        IERC20(payToken).approve(address(hopscotch), payTokenAmount);

        // Get uniswap call data
        bytes memory swapCallData = abi.encodeWithSelector(
            ISwapRouter.exactOutputSingle.selector,
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(payToken),
                tokenOut: address(WETH), // WETH swap output
                fee: 500,
                recipient: address(hopscotch),
                deadline: block.timestamp,
                amountOut: requestAmount,
                amountInMaximum: payTokenAmount,
                sqrtPriceLimitX96: 0
            })
        );

        // Bob pays the request with Uniswap 
        hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, address(payToken), payTokenAmount, UNISWAP_V3_ROUTER, swapCallData));

        // Make sure the request has been paid
        (,,,bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        uint256 recipientRequestTokenIncreace = alice.balance - aliceRequestTokenBalanceBefore;

        assertEq(recipientRequestTokenIncreace, requestAmount);
    }

    function testPayErc20RequestWithNativeUniswapSwap() public {
        address requestToken = DAI;
        uint256 requestAmount = 10000000;

        address payToken = address(0);
        uint256 payTokenAmount = 1000000000;

        // Alice create the request
        vm.prank(alice);
        uint256 id = hopscotch.createRequest(requestToken, requestAmount);

        // Bob is going to pay it
        vm.startPrank(bob);

        // Capture unpaid request balances
        uint256 aliceRequestTokenBalanceBefore = IERC20(requestToken).balanceOf(alice);

        // Get uniswap call data
        bytes memory swapCallData = abi.encodeWithSelector(
            ISwapRouter.exactOutputSingle.selector,
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(WETH),
                tokenOut: address(requestToken),
                fee: 500,
                recipient: address(hopscotch),
                deadline: block.timestamp,
                amountOut: requestAmount,
                amountInMaximum: payTokenAmount,
                sqrtPriceLimitX96: 0
            })
        );

        // Bob pays the request with Uniswap 
        hopscotch.payRequest{value: payTokenAmount}(IHopscotch.PayRequestInputParams(id, address(payToken), payTokenAmount, UNISWAP_V3_ROUTER, swapCallData));

        // Make sure the request has been paid
        (,,,bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        uint256 recipientRequestTokenIncreace = IERC20(requestToken).balanceOf(alice) - aliceRequestTokenBalanceBefore;

        assertEq(recipientRequestTokenIncreace, requestAmount);
    }
}
