// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
// import "forge-std/StdCheats.sol";
import "../src/Hopscotch.sol";
import {ISwapRouter} from "uniswap-v3-periphery/interfaces/ISwapRouter.sol";

// forge test --fork-url http://localhost:8545 -vvvvv

contract HopscotchTest is Test {
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant UNISWAP_V3_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;

    uint8 public constant DAI_DECIMALS = 8;
    uint8 public constant USDC_DECIMALS = 18;

    uint256 public constant MINT_AMMOUNT = 10000e18;

    IHopscotch public hopscotch;
    address acct0;
    address acct1;
    address acct2;

    function setUp() public {
        acct0 = vm.addr(1);
        acct1 = vm.addr(2);
        acct2 = vm.addr(3);

        vm.prank(acct0);
        hopscotch = new Hopscotch();

        deal(DAI, acct0, MINT_AMMOUNT);
        deal(USDC, acct0, MINT_AMMOUNT);

        deal(DAI, acct1, MINT_AMMOUNT);
        deal(USDC, acct1, MINT_AMMOUNT);

        deal(DAI, acct2, MINT_AMMOUNT);
        deal(USDC, acct2, MINT_AMMOUNT);
    }

    function testErc20Balance() public {
        assertEq(IERC20(DAI).balanceOf(address(acct0)), MINT_AMMOUNT);
        assertEq(IERC20(DAI).balanceOf(address(acct1)), MINT_AMMOUNT);
        assertEq(IERC20(DAI).balanceOf(address(acct2)), MINT_AMMOUNT);
    }

    function testCreateRequest() public {
        uint256 requestAmount = 1 * 10**DAI_DECIMALS;

        vm.prank(acct1);
        uint256 id = hopscotch.createRequest(IERC20(DAI), requestAmount);

        (
            address recipient,
            address recipientToken,
            uint256 recipientTokenAmount,
            bool paid
        ) = hopscotch.getRequest(id);

        assertEq(recipient, acct1);
        assertEq(recipientToken, DAI);
        assertEq(recipientTokenAmount, requestAmount);
        assertEq(paid, false);
    }

    function testPayRequestDirect() public {
        uint256 requestAmount = 1 * 10**DAI_DECIMALS;

        vm.prank(acct1);
        uint256 id = hopscotch.createRequest(IERC20(DAI), requestAmount);

        vm.startPrank(acct2);
        IERC20(DAI).approve(address(hopscotch), 2 * requestAmount);
        hopscotch.payRequest(id);

        (, , , bool paid) = hopscotch.getRequest(id);
        assertTrue(paid);
    }

    function testPayRequestDirectNoApproval() public {
        uint256 requestAmount = 1 * 10**DAI_DECIMALS;

        vm.prank(acct1);
        uint256 id = hopscotch.createRequest(IERC20(DAI), requestAmount);

        vm.startPrank(acct2);
        vm.expectRevert();
        hopscotch.payRequest(id);

        (, , , bool paid) = hopscotch.getRequest(id);
        assertFalse(paid);
    }

    function testPayRequestSwap() public {
        uint256 requestAmount = 1 * 10**DAI_DECIMALS;
        uint256 inputAmount = 2 * 10**USDC_DECIMALS; // max

        address recipient = acct1;
        address sender = acct2;

        // Capture unpaid request balances
        uint256 recipientRequestTokenBalanceBefore = IERC20(DAI).balanceOf(
            recipient
        );

        // Create request
        vm.prank(recipient);
        uint256 id = hopscotch.createRequest(IERC20(DAI), requestAmount);

        vm.startPrank(sender);

        // Approve input amount
        IERC20(USDC).approve(address(hopscotch), inputAmount);

        // Get swap call data
        bytes memory swapCallData = abi.encodeWithSelector(
            ISwapRouter.exactOutputSingle.selector,
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: USDC,
                tokenOut: DAI,
                fee: 500,
                recipient: address(hopscotch),
                deadline: block.timestamp,
                amountOut: requestAmount,
                amountInMaximum: inputAmount,
                sqrtPriceLimitX96: 0
            })
        );

        // Call pay with swap
        hopscotch.payRequest(
            id,
            IERC20(USDC),
            inputAmount,
            UNISWAP_V3_ROUTER,
            swapCallData
        );

        // Make sure the request has been paid
        (, , uint256 recipientTokenAmount, bool paid) = hopscotch.getRequest(
            id
        );
        assertTrue(paid);

        uint256 recipientRequestTokenIncreace = IERC20(DAI).balanceOf(
            recipient
        ) - recipientRequestTokenBalanceBefore;

        assertEq(recipientRequestTokenIncreace, recipientTokenAmount);
    }
}
