// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IWrappedNativeToken} from "./IWrappedNativeToken.sol";

interface IHopscotch {
    /// @notice Emitted when a request is created
    /// @param requestId id of the created request
    /// @param recipient recipient of the request
    /// @param recipientToken requested token, zero if it is the native asset
    /// @param recipientTokenAmount requested token amount
    event RequestCreated(
        uint256 indexed requestId,
        address indexed recipient,
        address recipientToken,
        uint256 recipientTokenAmount
    );

    /// @notice Emitted when a request is paid
    /// @param requestId id of the paid request
    /// @param sender sender of the request
    /// @param senderToken sender token, zero address if it was the native asset
    /// @param senderTokenAmount sender token amount
    event RequestPaid(
        uint256 indexed requestId,
        address indexed sender,
        address senderToken,
        uint256 senderTokenAmount
    );

    /// @notice Emitted when tokens are withdraw from this contract
    /// @param token token being withdrawn, zero address for native asset
    /// @param to where is the withdraw is going to
    /// @param amount amount being withdrawn
    event Withdraw(IERC20 indexed token, address indexed to, uint256 amount);

    /// @notice Create a request for a given token and token amount to be paid to msg.sender
    /// @param recipientToken token being requested, zero address for the native asset
    /// @param recipientTokenAmount the amount of the request token being requested
    /// @dev The call will revert if:
    ///         * recipient token amount is 0
    ///       emits RequestCreated
    /// @return id request id that was created
    function createRequest(address recipientToken, uint256 recipientTokenAmount)
        external
        returns (uint256 id);

    /// @notice Pay the request at requestId using the swapContractAddress
    /// @param requestId id of the request to be paid
    /// @param inputToken input token the request is being paid with, use zero address if paying with the native asset
    /// @param inputTokenAmount amount of input token to pay the request, this should be the quoted amount for the swap data
    /// @param swapContractAddress address of the contract that will perform the swap
    ///                            if no swap is needed (sender and recipient tokens are the same, or just need wrapping/unwrapping), this will not be called
    /// @param swapContractCallData call data to pass into the swap contract that will perform the swap
    ///                             swap should be from ERC20->ERC20, wrapping and unwrapping is handled automatically
    ///                             if no swap is needed (sender and recipient tokens are the same, or just need wrapping/unwrapping), this is not necessairy
    /// @dev The call will revert if:
    ///         * inputTokenAmount is 0
    ///         * request has already been paid
    ///         * inputToken is the zero address, and msg.value != inputTokenAmount
    ///         * input token approval for this contract from msg.sender is less than inputTokenAmount (if not native)
    ///         * swapContractAddress called with swapContractCallData did not output at least the requests recipientTokenAmount of recipientToken
    ///         * TODO: there are more also...
    ///      Excess input or output tokens will be returned to msg.sender
    ///      emits RequestPaid
    function payRequest(
        uint256 requestId,
        address inputToken,
        uint256 inputTokenAmount,
        address swapContractAddress,
        bytes calldata swapContractCallData
    ) external payable;

    /// @notice Withdraw contract balance to the owner
    /// @dev The call will revert if:
    ///         * not called from the contract owner
    ///      emits Withdraw
    function withdraw() external;

    /// @notice Withdraw erc20 token balance to the owner
    /// @param token token to withdraw
    /// @dev The call will revert if:
    ///         * not called from the contract owner
    ///      emits Withdraw
    function withdrawToken(IERC20 token) external;

    /// @notice Get the request for the id
    /// @param requestId request id
    function getRequest(uint256 requestId)
        external
        view
        returns (
            address recipient,
            address recipientToken,
            uint256 recipientTokenAmount,
            bool paid
        );

    fallback() external payable;

    receive() external payable;
}
