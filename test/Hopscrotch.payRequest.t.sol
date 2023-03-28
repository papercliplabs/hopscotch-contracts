// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Hopscotch.sol";
import {IWrappedNativeToken} from "../src/IWrappedNativeToken.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockWrappedNativeToken} from "./mocks/MockWrappedNativeToken.sol";

import {ISwapRouter} from "uniswap-v3-periphery/interfaces/ISwapRouter.sol";

contract HopscotchPayRequestTest is Test {
    ////
    // Globals
    ////

    // Contracts under test
    IHopscotch public hopscotch;

    // Mock tokens
    MockWrappedNativeToken public wrappedNativeToken;
    MockERC20 public token0;
    MockERC20 public token1;

    // Users
    address deployer;
    address requester;
    address payer;

    // Expected events
    event RequestPaid(
        uint256 indexed requestId, address indexed sender, address senderToken, uint256 senderTokenAmount
    );

    ////
    // Setup
    ////

    function setUp() public {
        deployer = vm.addr(1);
        requester = vm.addr(2);
        payer = vm.addr(3);

        deal(deployer, 100e18);
        deal(requester, 100e18);
        deal(payer, 100e18);

        wrappedNativeToken = new MockWrappedNativeToken("Wrapped Ether", "WETH");
        vm.prank(requester);
        wrappedNativeToken.deposit{value: 10e18}();
        vm.prank(payer);
        wrappedNativeToken.deposit{value: 10e18}();

        token0 = new MockERC20("token0", "T0");
        token0.mint(requester, 100e18);
        token0.mint(payer, 100e18);

        token1 = new MockERC20("token1", "T1");
        token1.mint(requester, 100e18);
        token1.mint(payer, 100e18);

        vm.prank(deployer);
        hopscotch = new Hopscotch(address(wrappedNativeToken));
    }

    function test_SetupBalances() public {
        assertEq(wrappedNativeToken.balanceOf(requester), 10e18);
        assertEq(wrappedNativeToken.balanceOf(payer), 10e18);

        assertEq(token0.balanceOf(requester), 100e18);
        assertEq(token0.balanceOf(payer), 100e18);

        assertEq(token1.balanceOf(requester), 100e18);
        assertEq(token1.balanceOf(payer), 100e18);
    }

    ////
    // Passing tests
    ////

    function test_NativeRequestNativeExactPay() public {
        address _requestToken = address(0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(0);
        uint256 _payTokenAmount = 1e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Capture balance before request is paid
        uint256 requesterRequestTokenBalanceBefore = requester.balance;
        uint256 payerPayTokenBalanceBefore = payer.balance;

        // Pay the request
        vm.prank(payer);
        (
            uint256 refundedNativeTokenAmount,
            uint256 refundedErc20InputTokenAmount,
            uint256 refundedErc20OutputTokenAmount
        ) = hopscotch.payRequest{value: _payTokenAmount}(
            IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, address(0), "")
        );

        // Make sure the request has been marked as paid
        (,,, bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        // Make sure output balances are correct
        uint256 requesterRequestTokenBalanceIncreace = requester.balance - requesterRequestTokenBalanceBefore;
        uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - payer.balance;

        assertEq(requesterRequestTokenBalanceIncreace, _requestTokenAmount);
        assertEq(payerPayTokenBalanceDecreace, _requestTokenAmount);
        assertEq(refundedNativeTokenAmount, 0);
        assertEq(refundedErc20InputTokenAmount, 0);
        assertEq(refundedErc20OutputTokenAmount, 0);
    }

    function test_NativeRequestNativeOverPay() public {
        address _requestToken = address(0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(0);
        uint256 _payTokenAmount = 10e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Capture balance before request is paid
        uint256 requesterRequestTokenBalanceBefore = requester.balance;
        uint256 payerPayTokenBalanceBefore = payer.balance;

        // Pay the request
        vm.prank(payer);
        (
            uint256 refundedNativeTokenAmount,
            uint256 refundedErc20InputTokenAmount,
            uint256 refundedErc20OutputTokenAmount
        ) = hopscotch.payRequest{value: _payTokenAmount}(
            IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, address(0), "")
        );

        // Make sure the request has been marked as paid
        (,,, bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        // Make sure output balances are correct
        uint256 requesterRequestTokenBalanceIncreace = requester.balance - requesterRequestTokenBalanceBefore;
        uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - payer.balance;

        assertEq(requesterRequestTokenBalanceIncreace, _requestTokenAmount);
        assertEq(payerPayTokenBalanceDecreace, _requestTokenAmount);
        assertEq(refundedNativeTokenAmount, _payTokenAmount - _requestTokenAmount);
        assertEq(refundedErc20InputTokenAmount, 0);
        assertEq(refundedErc20OutputTokenAmount, 0);
    }

    function test_NativeRequestWrappedNativeExactPay() public {
        address _requestToken = address(0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(wrappedNativeToken);
        uint256 _payTokenAmount = _requestTokenAmount;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Capture balance before request is paid
        uint256 requesterRequestTokenBalanceBefore = requester.balance;
        uint256 payerPayTokenBalanceBefore = IERC20(_payToken).balanceOf(payer);

        // Approve pay token
        vm.prank(payer);
        IERC20(_payToken).approve(address(hopscotch), _payTokenAmount);

        // Pay the request
        vm.prank(payer);
        (
            uint256 refundedNativeTokenAmount,
            uint256 refundedErc20InputTokenAmount,
            uint256 refundedErc20OutputTokenAmount
        ) = hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, address(0), ""));

        // Make sure the request has been marked as paid
        (,,, bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        // Make sure output balances are correct
        uint256 requesterRequestTokenBalanceIncreace = requester.balance - requesterRequestTokenBalanceBefore;
        uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - IERC20(_payToken).balanceOf(payer);

        assertEq(requesterRequestTokenBalanceIncreace, _requestTokenAmount);
        assertEq(payerPayTokenBalanceDecreace, _requestTokenAmount);
        assertEq(refundedNativeTokenAmount, 0);
        assertEq(refundedErc20InputTokenAmount, 0);
        assertEq(refundedErc20OutputTokenAmount, 0);
    }

    function test_NativeRequestWrappedNativeOverPay() public {
        address _requestToken = address(0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(wrappedNativeToken);
        uint256 _payTokenAmount = _requestTokenAmount + 1e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Capture balance before request is paid
        uint256 requesterRequestTokenBalanceBefore = requester.balance;
        uint256 payerPayTokenBalanceBefore = IERC20(_payToken).balanceOf(payer);

        // Approve pay token
        vm.prank(payer);
        IERC20(_payToken).approve(address(hopscotch), _payTokenAmount);

        // Pay the request
        vm.prank(payer);
        (
            uint256 refundedNativeTokenAmount,
            uint256 refundedErc20InputTokenAmount,
            uint256 refundedErc20OutputTokenAmount
        ) = hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, address(0), ""));

        // Make sure the request has been marked as paid
        (,,, bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        // Make sure output balances are correct
        uint256 requesterRequestTokenBalanceIncreace = requester.balance - requesterRequestTokenBalanceBefore;
        uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - IERC20(_payToken).balanceOf(payer);

        assertEq(requesterRequestTokenBalanceIncreace, _requestTokenAmount);
        assertEq(payerPayTokenBalanceDecreace, _payTokenAmount); // Entire input amount was used
        assertEq(refundedNativeTokenAmount, _payTokenAmount - _requestTokenAmount); // Refunded some output
        assertEq(refundedErc20InputTokenAmount, 0);
        assertEq(refundedErc20OutputTokenAmount, 0);
    }

    function test_WrappedNativeRequestNativeExactPay() public {}

    function test_WrappedNativeRequestNativeOverPay() public {}

    function test_ERC20RequestERC20DirectExactPay() public {}

    function test_ERC20RequestERC20DirectOverPay() public {}

    function test_NativeRequestERC20SwapPay() public {}

    function test_ERC20RequestERC20SwapPay() public {}

    ////
    // Failing tests
    ////

    ////
    // Fuzz tests
    ////

    ////
    // Fork tests
    ////

    // // RPC's
    // string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    // string GOERLI_RPC_URL = vm.envString("GOERLI_RPC_URL");

    // // Forks
    // uint256 mainnetFork;
    // uint256 goerliFork;

    // // Fork blocksetERC20TestTokens numbers
    // uint256 mainnetBlockNumber = 16457587;
    // uint256 goerliBlockNumber = 8594778;

    // // Tokens
    // address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    // address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // // Users
    // address alice;
    // address bob;
    // address matt;

    // // External contracts
    // address public constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    // // Contracts under test
    // IHopscotch public hopscotch;

    // // Constants
    // uint256 public constant ERC20_MINT_AMMOUNT = 1e25;

    // // Expected events
    // event RequestCreated(
    //     uint256 indexed requestId,
    //     address indexed recipient,
    //     address indexed recipientToken,
    //     uint256 recipientTokenAmount
    // );

    // // Helpers
    // function selectMainnetFork() public {
    //     vm.selectFork(mainnetFork);
    //     vm.rollFork(mainnetBlockNumber);
    // }

    // function selectGoerliFork() public {
    //     vm.selectFork(goerliFork);
    //     vm.rollFork(goerliBlockNumber);
    // }

    // function generateUsers() public {
    //     // Assign users
    //     alice = vm.addr(1);
    //     bob = vm.addr(2);
    //     matt = vm.addr(3);

    //     // Mint initial ERC20's, matt is broke

    //     deal(alice, ERC20_MINT_AMMOUNT);
    //     deal(bob, ERC20_MINT_AMMOUNT);
    // }

    // // Setup
    // function setUp() public {
    //     // Create forks
    //     mainnetFork = vm.createFork(MAINNET_RPC_URL);
    //     goerliFork = vm.createFork(GOERLI_RPC_URL);

    //     selectMainnetFork();
    //     generateUsers();
    //     vm.prank(alice);
    //     hopscotch = new Hopscotch(WETH);
    //     deal(address(10), alice, ERC20_MINT_AMMOUNT);
    //     deal(DAI, bob, ERC20_MINT_AMMOUNT);

    //     deal(USDC, alice, ERC20_MINT_AMMOUNT);
    //     deal(USDC, bob, ERC20_MINT_AMMOUNT);

    //     deal(WETH, alice, ERC20_MINT_AMMOUNT);
    //     deal(WETH, bob, ERC20_MINT_AMMOUNT);
    // }

    // // Setup Tests
    // function test_CanSelectFork() public {
    //     selectMainnetFork();

    //     assertEq(vm.activeFork(), mainnetFork);
    //     assertEq(block.number, mainnetBlockNumber);
    // }

    // function test_DealErc20() public {
    //     assertEq(IERC20(DAI).balanceOf(address(alice)), ERC20_MINT_AMMOUNT);
    //     assertEq(IERC20(DAI).balanceOf(address(bob)), ERC20_MINT_AMMOUNT);
    //     assertEq(IERC20(DAI).balanceOf(address(matt)), 0);

    //     assertEq(IERC20(USDC).balanceOf(address(alice)), ERC20_MINT_AMMOUNT);
    //     assertEq(IERC20(USDC).balanceOf(address(bob)), ERC20_MINT_AMMOUNT);
    //     assertEq(IERC20(USDC).balanceOf(address(matt)), 0);
    // }

    // // Contract tests
    // function test_PayNativeRequestDirectlyExact() public {
    //     address requester = alice;
    //     address requestToken = address(0);
    //     uint256 requestTokenAmount = 10000000;

    //     address payer = bob;
    //     address payToken = address(0);
    //     uint256 payTokenAmount = 10000000;

    //     // Capture unpaid balances
    //     uint256 requesterRequestTokenBalanceBefore = requester.balance;
    //     uint256 payerPayTokenBalanceBefore = payer.balance;

    //     vm.prank(requester);
    //     uint256 id = hopscotch.createRequest(requestToken, requestTokenAmount);

    //     vm.startPrank(payer);

    //     // Payer pays the request, don't need swap
    //     (uint256 refundedNativeAmount, uint256 refundedErc20InputAmount, uint256 refundedErc20OutputAmount) = hopscotch
    //         .payRequest{value: payTokenAmount}(
    //         IHopscotch.PayRequestInputParams(id, address(payToken), requestTokenAmount, address(0), "")
    //     );

    //     // Make sure the request has been paid
    //     (,,, bool paid) = hopscotch.getRequest(id);
    //     assertTrue(paid);

    //     uint256 requesterRequestTokenBalanceIncreace = requester.balance - requesterRequestTokenBalanceBefore;
    //     uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - payer.balance;

    //     assertEq(requesterRequestTokenBalanceIncreace, requestTokenAmount);
    //     assertEq(payerPayTokenBalanceDecreace, requestTokenAmount);
    //     assertEq(refundedNativeAmount, 0);
    //     assertEq(refundedErc20InputAmount, 0);
    //     assertEq(refundedErc20OutputAmount, 0);
    // }

    // function test_PayNativeRequestDirectlyOverpay() public {
    //     address requester = alice;
    //     address requestToken = address(0);
    //     uint256 requestTokenAmount = 10000000;

    //     address payer = bob;
    //     address payToken = address(0);
    //     uint256 payTokenAmount = 110000000;

    //     // Capture unpaid balances
    //     uint256 requesterRequestTokenBalanceBefore = requester.balance;
    //     uint256 payerPayTokenBalanceBefore = payer.balance;

    //     vm.prank(requester);
    //     uint256 id = hopscotch.createRequest(requestToken, requestTokenAmount);

    //     vm.startPrank(payer);

    //     // Payer pays the request, don't need swap
    //     (uint256 refundedNativeAmount, uint256 refundedErc20InputAmount, uint256 refundedErc20OutputAmount) = hopscotch
    //         .payRequest{value: payTokenAmount}(
    //         IHopscotch.PayRequestInputParams(id, address(payToken), payTokenAmount, address(0), "")
    //     );

    //     // Make sure the request has been paid
    //     (,,, bool paid) = hopscotch.getRequest(id);
    //     assertTrue(paid);

    //     uint256 requesterRequestTokenBalanceIncreace = requester.balance - requesterRequestTokenBalanceBefore;
    //     uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - payer.balance;

    //     assertEq(requesterRequestTokenBalanceIncreace, requestTokenAmount);
    //     assertEq(payerPayTokenBalanceDecreace, requestTokenAmount);
    //     assertEq(refundedNativeAmount, payTokenAmount - requestTokenAmount);
    //     assertEq(refundedErc20InputAmount, 0);
    //     assertEq(refundedErc20OutputAmount, 0);
    // }

    // function test_RevertPayNativeRequestDirectlyUnderpay() public {
    //     address requester = alice;
    //     address requestToken = address(0);
    //     uint256 requestTokenAmount = 10000000;

    //     address payer = bob;
    //     address payToken = address(0);
    //     uint256 payTokenAmount = 100000;

    //     vm.prank(requester);
    //     uint256 id = hopscotch.createRequest(requestToken, requestTokenAmount);

    //     vm.startPrank(payer);

    //     // Payer pays the request, don't need swap
    //     vm.expectRevert();
    //     hopscotch.payRequest{value: payTokenAmount}(
    //         IHopscotch.PayRequestInputParams(id, address(requestToken), payTokenAmount, address(payToken), "")
    //     );
    // }

    // function test_PayErc20RequestDirectlyExact() public {
    //     selectMainnetFork();

    //     address requester = alice;
    //     address requestToken = DAI;
    //     uint256 requestTokenAmount = 10000000;

    //     address payer = bob;
    //     address payToken = address(0);
    //     uint256 payTokenAmount = 110000000;

    //     // Create the request
    //     vm.prank(requester);
    //     uint256 id = hopscotch.createRequest(requestToken, requestTokenAmount);

    //     vm.startPrank(payer);

    //     // Capture unpaid request balances
    //     uint256 requesterRequestTokenBalanceBefore = IERC20(requestToken).balanceOf(requester);
    //     uint256 payerPayTokenBalanceBefore = IERC20(payToken).balanceOf(payer);

    //     // Approve input amount
    //     IERC20(requestToken).approve(address(hopscotch), requestTokenAmount);

    //     // Payer pays the request, don't need swap
    //     (uint256 refundedNativeAmount, uint256 refundedErc20InputAmount, uint256 refundedErc20OutputAmount) = hopscotch
    //         .payRequest(IHopscotch.PayRequestInputParams(id, address(requestToken), requestTokenAmount, address(0), ""));

    //     // Make sure the request has been paid
    //     (,,, bool paid) = hopscotch.getRequest(id);
    //     assertTrue(paid);

    //     uint256 recipientRequestTokenIncreace =
    //         IERC20(requestToken).balanceOf(requester) - requesterRequestTokenBalanceBefore;
    //     uint256 payerPayTokenDecreace = IERC20(payToken).balanceOf(payer) - payerPayTokenBalanceBefore;

    //     assertEq(recipientRequestTokenIncreace, requestTokenAmount);
    //     assertEq(payerPayTokenDecreace, requestTokenAmount);
    //     assertEq(refundedNativeAmount, 0);
    //     assertEq(refundedErc20InputAmount, 0);
    //     assertEq(refundedErc20OutputAmount, 0);
    // }

    // function testPayNativeRequestWithWrappedNative() public {
    //     address requestToken = address(0);
    //     uint256 requestTokenAmount = 10000000;

    //     // Alice create the request
    //     vm.prank(alice);
    //     uint256 id = hopscotch.createRequest(requestToken, requestTokenAmount);

    //     // Bob is going to pay it
    //     vm.startPrank(bob);

    //     // Capture unpaid request balances
    //     uint256 aliceRequestTokenBalanceBefore = alice.balance;

    //     // Approve input amount
    //     IERC20(WETH).approve(address(hopscotch), requestTokenAmount);

    //     // Bob pays the request, don't need swap
    //     hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, WETH, requestTokenAmount, address(0), ""));

    //     // Make sure the request has been paid
    //     (,,, bool paid) = hopscotch.getRequest(id);
    //     assertTrue(paid);

    //     uint256 recipientRequestTokenIncreace = alice.balance - aliceRequestTokenBalanceBefore;

    //     assertEq(recipientRequestTokenIncreace, requestTokenAmount);
    // }

    // function testPayWrappedNativeRequestWithNative() public {
    //     address requestToken = WETH;
    //     uint256 requestTokenAmount = 10000000;

    //     // Alice create the request
    //     vm.prank(alice);
    //     uint256 id = hopscotch.createRequest(requestToken, requestTokenAmount);

    //     // Bob is going to pay it
    //     vm.startPrank(bob);

    //     // Capture unpaid request balances
    //     uint256 aliceRequestTokenBalanceBefore = IERC20(requestToken).balanceOf(alice);

    //     // Bob pays the request, don't need swap
    //     hopscotch.payRequest{value: requestTokenAmount}(
    //         IHopscotch.PayRequestInputParams(id, address(0), requestTokenAmount, address(0), "")
    //     );

    //     // Make sure the request has been paid
    //     (,,, bool paid) = hopscotch.getRequest(id);
    //     assertTrue(paid);

    //     uint256 recipientRequestTokenIncreace = IERC20(requestToken).balanceOf(alice) - aliceRequestTokenBalanceBefore;

    //     assertEq(recipientRequestTokenIncreace, requestTokenAmount);
    // }

    // function testPayErc20RequestWithErc20UniswapSwap() public {
    //     address requestToken = DAI;
    //     uint256 requestTokenAmount = 10000000;

    //     address payToken = USDC;
    //     uint256 payTokenAmount = 1000000000;

    //     // Alice create the request
    //     vm.prank(alice);
    //     uint256 id = hopscotch.createRequest(requestToken, requestTokenAmount);

    //     // Bob is going to pay it
    //     vm.startPrank(bob);

    //     // Capture unpaid request balances
    //     uint256 aliceRequestTokenBalanceBefore = IERC20(requestToken).balanceOf(alice);

    //     // Approve input amount
    //     IERC20(payToken).approve(address(hopscotch), payTokenAmount);

    //     // Get uniswap call data
    //     bytes memory swapCallData = abi.encodeWithSelector(
    //         ISwapRouter.exactOutputSingle.selector,
    //         ISwapRouter.ExactOutputSingleParams({
    //             tokenIn: address(payToken),
    //             tokenOut: address(requestToken),
    //             fee: 500,
    //             recipient: address(hopscotch),
    //             deadline: block.timestamp,
    //             amountOut: requestTokenAmount,
    //             amountInMaximum: payTokenAmount,
    //             sqrtPriceLimitX96: 0
    //         })
    //     );

    //     // Bob pays the request with Uniswap
    //     hopscotch.payRequest(
    //         IHopscotch.PayRequestInputParams(id, address(payToken), payTokenAmount, UNISWAP_V3_ROUTER, swapCallData)
    //     );

    //     // Make sure the request has been paid
    //     (,,, bool paid) = hopscotch.getRequest(id);
    //     assertTrue(paid);

    //     uint256 recipientRequestTokenIncreace = IERC20(requestToken).balanceOf(alice) - aliceRequestTokenBalanceBefore;

    //     assertEq(recipientRequestTokenIncreace, requestTokenAmount);
    // }

    // function testPayNativeRequestWithErc20UniswapSwap() public {
    //     address requestToken = address(0);
    //     uint256 requestTokenAmount = 10000000;

    //     address payToken = USDC;
    //     uint256 payTokenAmount = 1000000000;

    //     // Alice create the request
    //     vm.prank(alice);
    //     uint256 id = hopscotch.createRequest(requestToken, requestTokenAmount);

    //     // Bob is going to pay it
    //     vm.startPrank(bob);

    //     // Capture unpaid request balances
    //     uint256 aliceRequestTokenBalanceBefore = alice.balance;

    //     // Approve input amount
    //     IERC20(payToken).approve(address(hopscotch), payTokenAmount);

    //     // Get uniswap call data
    //     bytes memory swapCallData = abi.encodeWithSelector(
    //         ISwapRouter.exactOutputSingle.selector,
    //         ISwapRouter.ExactOutputSingleParams({
    //             tokenIn: address(payToken),
    //             tokenOut: address(WETH), // WETH swap output
    //             fee: 500,
    //             recipient: address(hopscotch),
    //             deadline: block.timestamp,
    //             amountOut: requestTokenAmount,
    //             amountInMaximum: payTokenAmount,
    //             sqrtPriceLimitX96: 0
    //         })
    //     );

    //     // Bob pays the request with Uniswap
    //     hopscotch.payRequest(
    //         IHopscotch.PayRequestInputParams(id, address(payToken), payTokenAmount, UNISWAP_V3_ROUTER, swapCallData)
    //     );

    //     // Make sure the request has been paid
    //     (,,, bool paid) = hopscotch.getRequest(id);
    //     assertTrue(paid);

    //     uint256 recipientRequestTokenIncreace = alice.balance - aliceRequestTokenBalanceBefore;

    //     assertEq(recipientRequestTokenIncreace, requestTokenAmount);
    // }

    // function testPayErc20RequestWithNativeUniswapSwap() public {
    //     address requestToken = DAI;
    //     uint256 requestTokenAmount = 10000000;

    //     address payToken = address(0);
    //     uint256 payTokenAmount = 1000000000;

    //     // Alice create the request
    //     vm.prank(alice);
    //     uint256 id = hopscotch.createRequest(requestToken, requestTokenAmount);

    //     // Bob is going to pay it
    //     vm.startPrank(bob);

    //     // Capture unpaid request balances
    //     uint256 aliceRequestTokenBalanceBefore = IERC20(requestToken).balanceOf(alice);

    //     // Get uniswap call data
    //     bytes memory swapCallData = abi.encodeWithSelector(
    //         ISwapRouter.exactOutputSingle.selector,
    //         ISwapRouter.ExactOutputSingleParams({
    //             tokenIn: address(WETH),
    //             tokenOut: address(requestToken),
    //             fee: 500,
    //             recipient: address(hopscotch),
    //             deadline: block.timestamp,
    //             amountOut: requestTokenAmount,
    //             amountInMaximum: payTokenAmount,
    //             sqrtPriceLimitX96: 0
    //         })
    //     );

    //     // Bob pays the request with Uniswap
    //     hopscotch.payRequest{value: payTokenAmount}(
    //         IHopscotch.PayRequestInputParams(id, address(payToken), payTokenAmount, UNISWAP_V3_ROUTER, swapCallData)
    //     );

    //     // Make sure the request has been paid
    //     (,,, bool paid) = hopscotch.getRequest(id);
    //     assertTrue(paid);

    //     uint256 recipientRequestTokenIncreace = IERC20(requestToken).balanceOf(alice) - aliceRequestTokenBalanceBefore;

    //     assertEq(recipientRequestTokenIncreace, requestTokenAmount);
    // }
}
