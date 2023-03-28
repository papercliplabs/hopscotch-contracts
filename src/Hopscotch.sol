// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IHopscotch} from "./IHopscotch.sol";
import {IWrappedNativeToken} from "./IWrappedNativeToken.sol";

contract Hopscotch is IHopscotch {
    using SafeERC20 for IERC20;

    ////
    // Types
    ////

    struct Request {
        address payable recipient;
        address recipientToken;
        uint256 recipientTokenAmount;
        bool paid;
    }

    ////
    // Storage
    ////

    address public immutable wrappedNativeToken;
    Request[] requests;

    ////
    // Special
    ////

    /// @param _wrappedNativeToken wrapped native token address for the chain
    constructor(address _wrappedNativeToken) {
        wrappedNativeToken = _wrappedNativeToken;
    }

    fallback() external payable {}
    receive() external payable {}

    ////
    // Public functions
    ////

    function createRequest(address recipientToken, uint256 recipientTokenAmount) external returns (uint256 id) {
        require(recipientTokenAmount > 0, "createRequest/recipientTokenAmountZero");

        id = requests.length;
        requests.push(Request(payable(msg.sender), recipientToken, recipientTokenAmount, false));
        emit RequestCreated(id, msg.sender, recipientToken, recipientTokenAmount);
    }

    function payRequest(PayRequestInputParams calldata params)
        external
        payable
        returns (
            uint256 refundedNativeTokenAmount,
            uint256 refundedErc20InputTokenAmount,
            uint256 refundedErc20OutputTokenAmount
        )
    {
        Request storage request = requests[params.requestId];

        require(!request.paid, "payRequest/alreadyPaid");
        require(params.inputTokenAmount > 0, "payRequest/inputTokenAmountZero");

        request.paid = true;

        bool inputIsNative = (params.inputToken == address(0));
        bool outputIsNative = (request.recipientToken == address(0));

        if (inputIsNative) {
            require(
                address(this).balance >= params.inputTokenAmount, "payRequest/nativeTokenAmountLessThanInputTokenAmount"
            );

            if (!outputIsNative) {
                // Wrap native token
                IWrappedNativeToken(wrappedNativeToken).deposit{value: params.inputTokenAmount}();
            }
        } else {
            // Transfer tokens in
            IERC20(params.inputToken).safeTransferFrom(msg.sender, address(this), params.inputTokenAmount);
        }

        address erc20InputToken = inputIsNative ? wrappedNativeToken : params.inputToken;
        address erc20OutputToken = outputIsNative ? wrappedNativeToken : request.recipientToken;

        // Stright transfer if not overridden by swap below
        uint256 inputTokenAmountPaid = request.recipientTokenAmount;

        if (erc20InputToken != erc20OutputToken) {
            (inputTokenAmountPaid,) = performSwap(
                erc20InputToken,
                erc20OutputToken,
                params.inputTokenAmount,
                request.recipientTokenAmount,
                params.swapContractAddress,
                params.swapContractCallData
            );
        }

        if (outputIsNative) {
            if (!inputIsNative) {
                // Unwrap
                IWrappedNativeToken(wrappedNativeToken).withdraw(
                    IWrappedNativeToken(wrappedNativeToken).balanceOf(address(this))
                );
            }

            // Direct send
            require(address(this).balance >= request.recipientTokenAmount, "payRequest/notEnoughNativeTokens");
            (bool success,) = request.recipient.call{value: request.recipientTokenAmount}("");
            require(success, "payRequest/nativeTokenSendFailure");
        } else {
            // Direct transfer
            require(
                IERC20(request.recipientToken).balanceOf(address(this)) >= request.recipientTokenAmount,
                "payErc20RequestDirect/insufficientFunds"
            );
            IERC20(request.recipientToken).safeTransfer(request.recipient, request.recipientTokenAmount);
        }

        // Refund extra request
        uint256 nativeTokenBalance = address(this).balance;
        if (nativeTokenBalance > 0) {
            (bool success,) = payable(msg.sender).call{value: nativeTokenBalance}("");
            require(success, "payRequest/refundNative");
        }

        uint256 erc20InputTokenBalance = IERC20(erc20InputToken).balanceOf(address(this));
        if (erc20InputTokenBalance > 0) {
            IERC20(erc20InputToken).safeTransfer(msg.sender, erc20InputTokenBalance);
        }

        uint256 erc20OutputTokenBalance = IERC20(erc20OutputToken).balanceOf(address(this));
        if (erc20OutputTokenBalance > 0) {
            IERC20(request.recipientToken).safeTransfer(msg.sender, erc20OutputTokenBalance);
        }

        emit RequestPaid(params.requestId, msg.sender, params.inputToken, inputTokenAmountPaid);
        return (nativeTokenBalance, erc20InputTokenBalance, erc20OutputTokenBalance);
    }

    function getRequest(uint256 requestId)
        external
        view
        returns (address recipient, address recipientToken, uint256 recipientTokenAmount, bool paid)
    {
        Request storage request = requests[requestId];
        return (request.recipient, request.recipientToken, request.recipientTokenAmount, request.paid);
    }

    ////
    // Private functions
    ////

    /// @notice Perform a swap from inputToken to outputToken using the swapContractAddress with swapContractCallData
    /// @param inputToken input token to swap
    /// @param outputToken output token to swap to
    /// @param inputTokenAmountAllowance allowance of inputTokens given to swapContractAddress to perform the swap
    /// @param minimumOutputTokenAmountReceived minumum output token amount recieved from the swap
    /// @param swapContractAddress address of the contract that will perform the swap
    ///                            if no swap is needed due to input and recipient tokens being the same this will not be called
    /// @param swapContractCallData call data to pass into the swap contract that will perform the swap
    /// @dev The call will revert if
    ///         * inputToken balance of this contract is not at least inputTokenAmountAllowance
    ///         * outputToken balance of this contract is not increaced by at least minimumOutputTokenAmountReceived after the swap
    ///         * swapContract call reverts
    /// @return inputTokenAmountPaid amount of input tokens paid for the swap
    /// @return outputTokenAmountReceived amount of output tokens recieved from the swap
    function performSwap(
        address inputToken,
        address outputToken,
        uint256 inputTokenAmountAllowance,
        uint256 minimumOutputTokenAmountReceived,
        address swapContractAddress,
        bytes calldata swapContractCallData
    ) internal returns (uint256 inputTokenAmountPaid, uint256 outputTokenAmountReceived) {
        // Grab balances before swap to compare with after
        uint256 inputTokenBalanceBeforeSwap = IERC20(inputToken).balanceOf(address(this));
        uint256 outputTokenBalanceBeforeSwap = IERC20(outputToken).balanceOf(address(this));

        // Make sure this contract holds enough input tokens
        require(inputTokenBalanceBeforeSwap >= inputTokenAmountAllowance, "performSwap/notEnoughInputTokens");

        // Allow swap contract to spend this amount of swap input tokens
        IERC20(inputToken).approve(swapContractAddress, inputTokenAmountAllowance);

        // Execute swap
        (bool swapSuccess, bytes memory result) = swapContractAddress.call(swapContractCallData);

        // Revert with the reason returned by the call
        if (!swapSuccess) {
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (result.length < 68) revert();
            assembly {
                result := add(result, 0x04)
            }
            revert(abi.decode(result, (string)));
        }

        // Check output balance increaced by at least request amount
        inputTokenAmountPaid = inputTokenBalanceBeforeSwap - IERC20(inputToken).balanceOf(address(this));
        outputTokenAmountReceived = IERC20(outputToken).balanceOf(address(this)) - outputTokenBalanceBeforeSwap;

        require(
            outputTokenAmountReceived >= minimumOutputTokenAmountReceived, "performSwap/notEnoughOutputTokensFromSwap"
        );

        // Revoke input token approval
        IERC20(inputToken).approve(swapContractAddress, 0);
    }
}
