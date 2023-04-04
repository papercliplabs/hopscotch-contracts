// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IWrappedNativeToken} from "./IWrappedNativeToken.sol";

interface IHopscotch {
    ////
    // Types
    ////

    /// @param requestId id of the request to be paid
    /// @param inputToken input token the request is being paid with, use zero address for native token
    /// @param inputTokenAmount amount of input token to pay the request, this should be the quoted amount for the swap data
    /// @param swapContractAddress address of the contract that will perform the swap
    ///                            if no swap is needed due to input and recipient tokens being the same this will not be called
    /// @param swapContractCallData call data to pass into the swap contract that will perform the swap
    struct PayRequestInputParams {
        uint256 requestId;
        address inputToken;
        uint256 inputTokenAmount;
        address swapContractAddress;
        bytes swapContractCallData;
    }

    ////
    // Events
    ////

    /// @notice Emitted when a request is created
    /// @param requestId id of the created request
    /// @param recipient recipient of the request
    /// @param recipientToken requested token, zero if it is the native asset
    /// @param recipientTokenAmount requested token amount
    event RequestCreated(
        uint256 indexed requestId,
        address indexed recipient,
        address indexed recipientToken,
        uint256 recipientTokenAmount
    );

    /// @notice Emitted when a request is paid
    /// @param requestId id of the paid request
    /// @param sender sender of the request
    /// @param senderToken sender token, zero address if it was the native asset
    /// @param senderTokenAmount sender token amount used to pay the request
    event RequestPaid(
        uint256 indexed requestId, address indexed sender, address senderToken, uint256 senderTokenAmount
    );

    ////
    // Public function declarations
    ////

    /// @notice Create a request for a given token and token amount to be paid to msg.sender
    /// @param recipientToken token being requested, use zero address for native token
    /// @param recipientTokenAmount the amount of the request token being requested
    /// @dev The call will revert if:
    ///         * recipient token amount is 0
    ///       emits RequestCreated
    /// @return id request id that was created
    function createRequest(address recipientToken, uint256 recipientTokenAmount) external returns (uint256 id);

    /// @notice Pay the request at requestId using the swapContractAddress
    /// @param params params
    /// @dev The call will revert if:
    ///         * request for requestId does not exist
    ///         * request has already been paid
    ///         * inputTokenAmount is 0
    ///         * input token approval for this contract from msg.sender is less than inputTokenAmount
    ///         * insufficient input token balance
    ///         * swapContractAddress called with swapContractCallData did not output at least the requests recipientTokenAmount of recipientToken
    ///      Excess input or output tokens will be returned to msg.sender
    ///      This will automatically wrap ETH asset if the inputTokenAddress is WETH9 and at least the inputTokenAmount of ETH was sent in
    ///      emits RequestPaid
    /// @return refundedNativeTokenAmount amount of native token refunded to msg.sender
    /// @return refundedErc20InputTokenAmount amount of input token refunded to msg.sender
    /// @return refundedErc20OutputTokenAmount amount of output token refunded to msg.sender
    function payRequest(PayRequestInputParams calldata params)
        external
        payable
        returns (
            uint256 refundedNativeTokenAmount,
            uint256 refundedErc20InputTokenAmount,
            uint256 refundedErc20OutputTokenAmount
        );

    /// @notice Get the request for the id
    /// @param requestId request id
    function getRequest(uint256 requestId)
        external
        view
        returns (address recipient, address recipientToken, uint256 recipientTokenAmount, bool paid);
}
