// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

interface IHopscotch {
    /// @notice Emitted when a request is created
    /// @param requestId id of the created request
    /// @param recipient recipient of the request
    /// @param recipientToken requested token
    /// @param recipientTokenAmount requested token amount
    event RequestCreated(
        uint256 indexed requestId,
        address indexed recipient,
        IERC20 recipientToken,
        uint256 recipientTokenAmount
    );

    /// @notice Emitted when a request is paid
    /// @param requestId id of the paid request
    /// @param sender sender of the request
    /// @param senderToken requested token
    /// @param senderTokenAmount requested token amount
    event RequestPaid(
        uint256 indexed requestId,
        address indexed sender,
        IERC20 senderToken,
        uint256 senderTokenAmount
    );

    /// @notice Emitted when the owner of this contract is changed
    /// @param oldOwner owner before the owner was changed
    /// @param newOwner owner after the owner was changed
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when tokens are withdraw from this contract
    /// @param token token being withdrawn, zero address for native asset
    /// @param to where is the withdraw is going to
    /// @param amount amount being withdrawn
    event Withdraw(address indexed token, address indexed to, uint256 amount);

    /// @notice Create a request for a given token and token amount to be paid to msg.sender
    /// @param recipientToken the token being requested
    /// @param recipientTokenAmount the amount of the request token being requested
    /// @dev The call will revert if:
    ///         * the recipient token is the zero address, or recipient token amount is 0
    ///         * the address does not correspond to an ERC20 token (TODO: implement?)
    ///       emits RequestCreated
    /// @return id request id that was created
    function createRequest(IERC20 recipientToken, uint256 recipientTokenAmount)
        external
        returns (uint256 id);

    /// @notice Pay the request at requestId using the swapContractAddress
    /// @param requestId id of the request to be paid
    /// @param inputToken input token address the request is being paid with
    /// @param inputTokenAmount amount of input token to pay the request, this should be the quoted amount for the swap data
    /// @param swapContractAddress address of the contract that will perform the swap
    /// @param swapContractCallData call data to pass into the swap contract that will perform the swap
    /// @dev The call will revert if:
    ///         * request has already been paid
    ///         * input token approval for this contract from msg.sender is less than inputTokenAmount (if not native)
    ///         * swapContractAddress called with swapContractCallData did not output at least the requests recipientTokenAmount of recipientToken
    ///      Excess input or output tokens will be returned to msg.sender
    ///      emits RequestPaid
    function payRequest(
        uint256 requestId,
        IERC20 inputToken,
        uint256 inputTokenAmount,
        address swapContractAddress,
        bytes calldata swapContractCallData
    ) external payable;

    /// @notice Pay the request at requestId directly using the requested token
    /// @param requestId id of the request to be paid
    /// @dev The call will revert if:
    ///         * request has already been paid
    ///         * requested token approval for this contract is less than the requested token amount (if not native)
    ///         * balance of the requested token is less than the requested token amount
    ///      emits RequestPaid
    function payRequest(uint256 requestId) external payable;

    /// @notice Set a new owner of this contract
    /// @param newOwner address of the new owner
    /// @dev The call will revert if:
    ///         * not called from the contract owner
    ///      emits OwnerChanged
    // function setOwner(address newOwner) external;

    /// @notice Withdraw contract balance to the owner
    /// @dev The call will revert if:
    ///         * not called from the contract owner
    ///      emits Withdraw
    function withdraw() external;

    /// @notice Withdraw erc20 token balance to the owner
    /// @param token to withdraw
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
