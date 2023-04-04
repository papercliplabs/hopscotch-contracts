// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Hopscotch.sol";
import {IWrappedNativeToken} from "../src/IWrappedNativeToken.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockWrappedNativeToken} from "./mocks/MockWrappedNativeToken.sol";
import {MockSwap} from "./mocks/MockSwap.sol";

import {ISwapRouter} from "uniswap-v3-periphery/interfaces/ISwapRouter.sol";

contract HopscotchPayRequestTest is Test {
    ////
    // Globals
    ////

    // Contracts under test
    IHopscotch public hopscotch;

    // Mocks
    MockWrappedNativeToken public wrappedNativeToken;
    MockERC20 public token0;
    MockERC20 public token1;
    MockSwap public mockSwap;

    // Users
    address deployer;
    address requester;
    address payer;
    address brokePayer;

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
        brokePayer = vm.addr(4);

        deal(deployer, 100e18);
        deal(requester, 100e18);
        deal(payer, 100e18);

        mockSwap = new MockSwap();

        wrappedNativeToken = new MockWrappedNativeToken("Wrapped Ether", "WETH");
        vm.prank(requester);
        wrappedNativeToken.deposit{value: 10e18}();
        vm.prank(payer);
        wrappedNativeToken.deposit{value: 20e18}();
        vm.prank(payer);
        wrappedNativeToken.transfer(address(mockSwap), 10e18);

        token0 = new MockERC20("token0", "T0");
        token0.mint(requester, 100e18);
        token0.mint(payer, 100e18);
        token0.mint(address(mockSwap), 100e18);

        token1 = new MockERC20("token1", "T1");
        token1.mint(requester, 100e18);
        token1.mint(payer, 100e18);
        token1.mint(address(mockSwap), 100e18);

        vm.prank(deployer);
        hopscotch = new Hopscotch(address(wrappedNativeToken));
    }

    function test_SetupBalances() public {
        assertEq(wrappedNativeToken.balanceOf(requester), 10e18);
        assertEq(wrappedNativeToken.balanceOf(payer), 10e18);
        assertEq(wrappedNativeToken.balanceOf(address(mockSwap)), 10e18);

        assertEq(token0.balanceOf(requester), 100e18);
        assertEq(token0.balanceOf(payer), 100e18);
        assertEq(token1.balanceOf(address(mockSwap)), 100e18);

        assertEq(token1.balanceOf(requester), 100e18);
        assertEq(token1.balanceOf(payer), 100e18);
        assertEq(token1.balanceOf(address(mockSwap)), 100e18);
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

    function test_WrappedNativeRequestNativeExactPay() public {
        address _requestToken = address(wrappedNativeToken);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(0);
        uint256 _payTokenAmount = _requestTokenAmount;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Capture balance before request is paid
        uint256 requesterRequestTokenBalanceBefore = IERC20(_requestToken).balanceOf(requester);
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
        uint256 requesterRequestTokenBalanceIncreace =
            IERC20(_requestToken).balanceOf(requester) - requesterRequestTokenBalanceBefore;
        uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - payer.balance;

        assertEq(requesterRequestTokenBalanceIncreace, _requestTokenAmount);
        assertEq(payerPayTokenBalanceDecreace, _payTokenAmount); // Entire input amount was used
        assertEq(refundedNativeTokenAmount, 0);
        assertEq(refundedErc20InputTokenAmount, 0);
        assertEq(refundedErc20OutputTokenAmount, 0);
    }

    function test_WrappedNativeRequestNativeOverPay() public {
        address _requestToken = address(wrappedNativeToken);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(0);
        uint256 _payTokenAmount = _requestTokenAmount + 1e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Capture balance before request is paid
        uint256 requesterRequestTokenBalanceBefore = IERC20(_requestToken).balanceOf(requester);
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
        uint256 requesterRequestTokenBalanceIncreace =
            IERC20(_requestToken).balanceOf(requester) - requesterRequestTokenBalanceBefore;
        uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - payer.balance;

        assertEq(requesterRequestTokenBalanceIncreace, _requestTokenAmount);
        assertEq(payerPayTokenBalanceDecreace, _payTokenAmount); // Entire input amount was used
        assertEq(refundedNativeTokenAmount, 0);
        assertEq(refundedErc20InputTokenAmount, _payTokenAmount - _requestTokenAmount);
        assertEq(refundedErc20OutputTokenAmount, 0);
    }

    function test_ERC20RequestERC20DirectExactPay() public {
        address _requestToken = address(token0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(token0);
        uint256 _payTokenAmount = _requestTokenAmount;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Capture balance before request is paid
        uint256 requesterRequestTokenBalanceBefore = IERC20(_requestToken).balanceOf(requester);
        uint256 payerPayTokenBalanceBefore = IERC20(_payToken).balanceOf(requester);

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
        uint256 requesterRequestTokenBalanceIncreace =
            IERC20(_requestToken).balanceOf(requester) - requesterRequestTokenBalanceBefore;
        uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - IERC20(_payToken).balanceOf(payer);

        assertEq(requesterRequestTokenBalanceIncreace, _requestTokenAmount);
        assertEq(payerPayTokenBalanceDecreace, _payTokenAmount); // Entire input amount was used
        assertEq(refundedNativeTokenAmount, 0);
        assertEq(refundedErc20InputTokenAmount, 0);
        assertEq(refundedErc20OutputTokenAmount, 0);
    }

    function test_ERC20RequestERC20DirectOverPay() public {
        address _requestToken = address(token0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(token0);
        uint256 _payTokenAmount = _requestTokenAmount + 1e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Capture balance before request is paid
        uint256 requesterRequestTokenBalanceBefore = IERC20(_requestToken).balanceOf(requester);
        uint256 payerPayTokenBalanceBefore = IERC20(_payToken).balanceOf(requester);

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
        uint256 requesterRequestTokenBalanceIncreace =
            IERC20(_requestToken).balanceOf(requester) - requesterRequestTokenBalanceBefore;
        uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - IERC20(_payToken).balanceOf(payer);

        assertEq(requesterRequestTokenBalanceIncreace, _requestTokenAmount);
        assertEq(payerPayTokenBalanceDecreace, _payTokenAmount - _requestTokenAmount); // Entire input amount was used
        assertEq(refundedNativeTokenAmount, 0);
        assertEq(refundedErc20InputTokenAmount, _payTokenAmount - _requestTokenAmount);
        assertEq(refundedErc20OutputTokenAmount, 0);
    }

    function test_NativeRequestERC20SwapPay() public {
        address _requestToken = address(0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(token0);
        uint256 _payTokenAmount = 10e8;

        uint256 _swapInputAmountConsumed = _payTokenAmount - 1e5;
        uint256 _swapOutputAmountReturned = _requestTokenAmount + 1e4;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Capture balance before request is paid
        uint256 requesterRequestTokenBalanceBefore = requester.balance;
        uint256 payerPayTokenBalanceBefore = IERC20(_payToken).balanceOf(payer);

        // Approve pay token
        vm.prank(payer);
        IERC20(_payToken).approve(address(hopscotch), _payTokenAmount);

        // Get swap call data
        bytes memory swapCallData = abi.encodeWithSelector(
            MockSwap.swap.selector,
            _payToken,
            _swapInputAmountConsumed,
            address(wrappedNativeToken),
            _swapOutputAmountReturned
        );

        // Pay the request
        vm.prank(payer);
        (
            uint256 refundedNativeTokenAmount,
            uint256 refundedErc20InputTokenAmount,
            uint256 refundedErc20OutputTokenAmount
        ) = hopscotch.payRequest(
            IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, address(mockSwap), swapCallData)
        );

        // Make sure the request has been marked as paid
        (,,, bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        // Make sure output balances are correct
        {
            uint256 requesterRequestTokenBalanceIncreace = requester.balance - requesterRequestTokenBalanceBefore;
            assertEq(requesterRequestTokenBalanceIncreace, _requestTokenAmount);
        }

        {
            uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - IERC20(_payToken).balanceOf(payer);
            assertEq(payerPayTokenBalanceDecreace, _swapInputAmountConsumed); // Entire input amount was used
            assertEq(refundedNativeTokenAmount, _swapOutputAmountReturned - _requestTokenAmount);
            assertEq(refundedErc20InputTokenAmount, _payTokenAmount - _swapInputAmountConsumed);
            assertEq(refundedErc20OutputTokenAmount, 0);
            assertEq(IERC20(_payToken).allowance(address(hopscotch), address(mockSwap)), 0);
        }
    }

    function test_ERC20RequestERC20SwapPay() public {
        address _requestToken = address(token0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(token1);
        uint256 _payTokenAmount = 10e8;

        uint256 _swapInputAmountConsumed = _payTokenAmount - 1e5;
        uint256 _swapOutputAmountReturned = _requestTokenAmount + 1e4;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Capture balance before request is paid
        uint256 requesterRequestTokenBalanceBefore = IERC20(_requestToken).balanceOf(requester);
        uint256 payerPayTokenBalanceBefore = IERC20(_payToken).balanceOf(payer);

        // Approve pay token
        vm.prank(payer);
        IERC20(_payToken).approve(address(hopscotch), _payTokenAmount);

        // Get swap call data
        bytes memory swapCallData = abi.encodeWithSelector(
            MockSwap.swap.selector, _payToken, _swapInputAmountConsumed, _requestToken, _swapOutputAmountReturned
        );

        // Pay the request
        vm.prank(payer);
        (
            uint256 refundedNativeTokenAmount,
            uint256 refundedErc20InputTokenAmount,
            uint256 refundedErc20OutputTokenAmount
        ) = hopscotch.payRequest(
            IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, address(mockSwap), swapCallData)
        );

        // Make sure the request has been marked as paid
        (,,, bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        // Make sure output balances are correct
        {
            uint256 requesterRequestTokenBalanceIncreace =
                IERC20(_requestToken).balanceOf(requester) - requesterRequestTokenBalanceBefore;
            assertEq(requesterRequestTokenBalanceIncreace, _requestTokenAmount);
        }

        {
            uint256 payerPayTokenBalanceDecreace = payerPayTokenBalanceBefore - IERC20(_payToken).balanceOf(payer);
            assertEq(payerPayTokenBalanceDecreace, _swapInputAmountConsumed);
            assertEq(refundedNativeTokenAmount, 0);
            assertEq(refundedErc20InputTokenAmount, _payTokenAmount - _swapInputAmountConsumed);
            assertEq(refundedErc20OutputTokenAmount, _swapOutputAmountReturned - _requestTokenAmount);
            assertEq(IERC20(_payToken).allowance(address(hopscotch), address(mockSwap)), 0);
        }
    }

    ////
    // Failing tests
    ////

    function testFail_RequestIdDoesNotExist() public {
        vm.prank(payer);
        hopscotch.payRequest(IHopscotch.PayRequestInputParams(100, address(token1), 1e18, address(0), ""));
    }

    function testFail_RequestAlreadyPaid() public {
        address _requestToken = address(token0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(token0);
        uint256 _payTokenAmount = _requestTokenAmount + 1e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Approve pay token
        vm.prank(payer);
        IERC20(_payToken).approve(address(hopscotch), _payTokenAmount);

        // Pay the request
        vm.prank(payer);
        hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, address(0), ""));

        // Make sure the request has been marked as paid
        (,,, bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);

        // Expect revert here
        hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, address(0), ""));
    }

    function testFail_InputTokenAmountZero() public {
        address _requestToken = address(token0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(token0);
        uint256 _payTokenAmount = _requestTokenAmount + 1e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Approve pay token
        vm.prank(payer);
        IERC20(_payToken).approve(address(hopscotch), _payTokenAmount);

        // Pay the request - expect revert since input token 0
        vm.prank(payer);
        hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, _payToken, 0, address(0), ""));
    }

    function testFail_MissingTokenApproval() public {
        address _requestToken = address(token0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(token0);
        uint256 _payTokenAmount = _requestTokenAmount + 1e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Pay the request - expect revert since didn't approve hopscotch to spend
        vm.prank(payer);
        hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, address(0), ""));
    }

    function testFail_InsufficentPayTokenBalance() public {
        address _requestToken = address(0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(wrappedNativeToken);
        uint256 _payTokenAmount = _requestTokenAmount + 1e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Approve pay token
        vm.prank(brokePayer);
        IERC20(_payToken).approve(address(hopscotch), _payTokenAmount);

        // Pay the request - expect revert since broke
        vm.prank(brokePayer);
        hopscotch.payRequest(IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, address(0), ""));
    }

    function testFail_SwapGaveLessThanRequest() public {
        address _requestToken = address(token0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(token1);
        uint256 _payTokenAmount = 10e8;

        uint256 _swapInputAmountConsumed = _payTokenAmount - 1e5;
        uint256 _swapOutputAmountReturned = _requestTokenAmount - 1e4;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotch.createRequest(_requestToken, _requestTokenAmount);

        // Approve pay token
        vm.prank(payer);
        IERC20(_payToken).approve(address(hopscotch), _payTokenAmount);

        // Get swap call data
        bytes memory swapCallData = abi.encodeWithSelector(
            MockSwap.swap.selector, _payToken, _swapInputAmountConsumed, _requestToken, _swapOutputAmountReturned
        );

        // Pay the request
        vm.prank(payer);
        hopscotch.payRequest(
            IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, address(mockSwap), swapCallData)
        );
    }

    ////
    // Fuzz tests
    ////

    ////
    // Fork tests
    ////

    function testFork_MainnetUniswapSwap() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        uint256 mainnetBlockNumber = 14700000;

        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

        vm.selectFork(mainnetFork);
        vm.rollFork(mainnetBlockNumber);

        vm.prank(deployer);
        IHopscotch hopscotchMainnet = new Hopscotch(WETH);

        deal(USDC, payer, 10e18);

        address _requestToken = DAI;
        uint256 _requestTokenAmount = 1e18;

        address _payToken = USDC;
        uint256 _payTokenAmount = 10e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotchMainnet.createRequest(_requestToken, _requestTokenAmount);

        // Approve pay token
        vm.prank(payer);
        IERC20(_payToken).approve(address(hopscotchMainnet), _payTokenAmount);

        // Get uniswap call data
        bytes memory swapCallData = abi.encodeWithSelector(
            ISwapRouter.exactOutputSingle.selector,
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(_payToken),
                tokenOut: address(_requestToken),
                fee: 500,
                recipient: address(hopscotchMainnet),
                deadline: block.timestamp,
                amountOut: _requestTokenAmount,
                amountInMaximum: _payTokenAmount,
                sqrtPriceLimitX96: 0
            })
        );

        // Pay the request
        vm.prank(payer);
        hopscotchMainnet.payRequest(
            IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, UNISWAP_V3_ROUTER, swapCallData)
        );

        // Make sure the request has been marked as paid
        (,,, bool paid) = hopscotchMainnet.getRequest(id);
        assertTrue(paid);
    }

    function testFork_PolygonUniswapSwapErc20Request() public {
        uint256 polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"));
        uint256 blockNumber = 40967486;

        address DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        address USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        address WETH = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        address UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

        vm.selectFork(polygonFork);
        vm.rollFork(blockNumber);

        vm.prank(deployer);
        IHopscotch hopscotchMainnet = new Hopscotch(WETH);

        deal(USDC, payer, 10e18);

        address _requestToken = DAI;
        uint256 _requestTokenAmount = 1e18;

        address _payToken = USDC;
        uint256 _payTokenAmount = 10e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotchMainnet.createRequest(_requestToken, _requestTokenAmount);

        // Approve pay token
        vm.prank(payer);
        IERC20(_payToken).approve(address(hopscotchMainnet), _payTokenAmount);

        // Get uniswap call data
        bytes memory swapCallData = abi.encodeWithSelector(
            ISwapRouter.exactOutputSingle.selector,
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(_payToken),
                tokenOut: address(_requestToken),
                fee: 500,
                recipient: address(hopscotchMainnet),
                deadline: block.timestamp,
                amountOut: _requestTokenAmount,
                amountInMaximum: _payTokenAmount,
                sqrtPriceLimitX96: 0
            })
        );

        // Pay the request
        vm.prank(payer);
        hopscotchMainnet.payRequest(
            IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, UNISWAP_V3_ROUTER, swapCallData)
        );

        // Make sure the request has been marked as paid
        (,,, bool paid) = hopscotchMainnet.getRequest(id);
        assertTrue(paid);
    }

    function testFork_PolygonUniswapSwapNativeRequest() public {
        uint256 polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"));
        uint256 blockNumber = 40967486;

        address DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        address USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        address WETH = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        address UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

        vm.selectFork(polygonFork);
        vm.rollFork(blockNumber);

        vm.prank(deployer);
        IHopscotch hopscotchMainnet = new Hopscotch(WETH);

        deal(USDC, payer, 10e18);

        address _requestToken = address(0);
        uint256 _requestTokenAmount = 1e8;

        address _payToken = USDC;
        uint256 _payTokenAmount = 10e8;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotchMainnet.createRequest(_requestToken, _requestTokenAmount);

        // Approve pay token
        vm.prank(payer);
        IERC20(_payToken).approve(address(hopscotchMainnet), _payTokenAmount);

        // Get uniswap call data
        bytes memory swapCallData = abi.encodeWithSelector(
            ISwapRouter.exactOutputSingle.selector,
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(_payToken),
                tokenOut: WETH,
                fee: 500,
                recipient: address(hopscotchMainnet),
                deadline: block.timestamp,
                amountOut: _requestTokenAmount,
                amountInMaximum: _payTokenAmount,
                sqrtPriceLimitX96: 0
            })
        );

        // Pay the request
        vm.prank(payer);
        hopscotchMainnet.payRequest(
            IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, UNISWAP_V3_ROUTER, swapCallData)
        );

        // Make sure the request has been marked as paid
        (,,, bool paid) = hopscotchMainnet.getRequest(id);
        assertTrue(paid);
    }

    function testFork_PolygonUniswapSwapErc20RequestNativePay() public {
        uint256 polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"));
        uint256 blockNumber = 40967486;

        address DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        address USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        address WETH = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        address UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

        vm.selectFork(polygonFork);
        vm.rollFork(blockNumber);

        vm.prank(deployer);
        IHopscotch hopscotchMainnet = new Hopscotch(WETH);

        deal(payer, 10e18);

        address _requestToken = DAI;
        uint256 _requestTokenAmount = 1e8;

        address _payToken = address(0);
        uint256 _payTokenAmount = 1e18;

        // Create a request
        vm.prank(requester);
        uint256 id = hopscotchMainnet.createRequest(_requestToken, _requestTokenAmount);

        // Get uniswap call data
        bytes memory swapCallData = abi.encodeWithSelector(
            ISwapRouter.exactOutputSingle.selector,
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: WETH,
                tokenOut: address(_requestToken),
                fee: 500,
                recipient: address(hopscotchMainnet),
                deadline: block.timestamp,
                amountOut: _requestTokenAmount,
                amountInMaximum: _payTokenAmount,
                sqrtPriceLimitX96: 0
            })
        );

        // Pay the request
        vm.prank(payer);
        hopscotchMainnet.payRequest{value: _payTokenAmount}(
            IHopscotch.PayRequestInputParams(id, _payToken, _payTokenAmount, UNISWAP_V3_ROUTER, swapCallData)
        );

        // Make sure the request has been marked as paid
        (,,, bool paid) = hopscotchMainnet.getRequest(id);
        assertTrue(paid);
    }
}
