// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IHopscotch} from "./IHopscotch.sol";
import {IWrappedNativeToken} from "./IWrappedNativeToken.sol";

contract Hopscotch is IHopscotch, Ownable {
    ////
    // Public structs 
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

    Request[] requests;
    address public immutable wrappedNativeToken;

    ////
    // Constructor 
    ////

    /// @param _wrappedNativeToken wrapped native token address for the chain
    constructor(address _wrappedNativeToken) {
        wrappedNativeToken = _wrappedNativeToken;
    }

    ////
    // Private functions 
    ////

    /// @notice Pay a native request directly with the native tokens held in this contract
    /// @param requestId id of the request to be paid
    /// @dev The call will revert if:
    ///         * request for requestId does not exist 
    ///         * request is not for the native tokens
    ///         * contract does not hold enough native tokens to fulfil the request 
    function payNativeRequestDirect(uint256 requestId) internal 
    {
        Request storage request = requests[requestId];

        require(request.recipientToken == address(0), "payNativeRequest/requestNotNative");
        require(address(this).balance >= request.recipientTokenAmount, "payNativeRequest/notEnoughNativeTokens");

        (bool success, ) = request.recipient.call{
            value: request.recipientTokenAmount
        }("");
        require(success, "payNativeRequest/nativeTokenSendFailure");
    }

    /// @notice Pay an erc20 request directly with the erc20 tokens held by this contract 
    /// @param requestId id of the request to be paid
    /// @dev The call will revert if:
    ///         * request for requestId does not exist 
    ///         * request is for the native tokens
    ///         * contract does not hold enough requestTokens to pay the request 
    function payErc20RequestDirect(uint256 requestId) internal
    {
        Request storage request = requests[requestId];

        require(request.recipientToken != address(0), "payErc20RequestDirect/requestIsNative");
        require(IERC20(request.recipientToken).balanceOf(address(this)) >= request.recipientTokenAmount, "payErc20RequestDirect/insufficientFunds");

        require(
            IERC20(request.recipientToken).transfer(request.recipient, request.recipientTokenAmount), "payErc20RequestDirect/transferFailed"
        );
    }

    /// @notice Perform a swap from inputToken to outputToken using the swapContractAddress with swapContractCallData  
    /// @param inputToken input token to swap
    /// @param outputToken output token to swap to
    /// @param inputTokenAmountAllowance allowance of inputTokens given to swapContractAddress to perform the swap
    /// @param minimumOutputTokenAmountReceived minumum output token amount recieved from the swap
    /// @param swapContractAddress address of the contract that will perform the swap
    ///                            if no swap is needed due to input and recipient tokens being the same this will not be called 
    /// @param swapContractCallData call data to pass into the swap contract that will perform the swap
    /// @dev The call will revert if
    ///         * inputToken is the same as outputToken
    ///         * inputToken balance of this contract is not at least inputTokenAmountAllowance
    ///         * outputToken balance of this contract is not increaced by at least minimumOutputTokenAmountReceived after the swap 
    ///         * swapContract call reverts
    /// @return inputTokenAmountPaid amount of input tokens paid for the swap
    /// @return outputTokenAmountReceived amount of output tokens recieved from the swap
    function performSwap(address inputToken, address outputToken, uint256 inputTokenAmountAllowance, uint256 minimumOutputTokenAmountReceived, address swapContractAddress, bytes calldata swapContractCallData) internal returns (uint256 inputTokenAmountPaid, uint256 outputTokenAmountReceived)
    {
        // Grab balances before swap to compare with after
        uint256 inputTokenBalanceBeforeSwap = IERC20(inputToken).balanceOf(address(this));
        uint256 outputTokenBalanceBeforeSwap = IERC20(outputToken).balanceOf(address(this));

        // Allow swap contract to spend this amount of swap input tokens
        IERC20(inputToken).approve(swapContractAddress, inputTokenAmountAllowance);

        // Execute swap
        (bool swapSuccess,) = swapContractAddress.call(swapContractCallData);
        require(swapSuccess, "performSwap/swap");

        // Check output balance increaced by at least request amount
        inputTokenAmountPaid = inputTokenBalanceBeforeSwap - IERC20(inputToken).balanceOf(address(this));
        outputTokenAmountReceived = IERC20(outputToken).balanceOf(address(this)) - outputTokenBalanceBeforeSwap;

        require(
            outputTokenAmountReceived >= minimumOutputTokenAmountReceived, "performSwap/notEnoughOutputTokensFromSwap"
        );

        // Revoke input token approval
        IERC20(inputToken).approve(swapContractAddress, 0);
    }

    ////
    // Public functions 
    ////

    function createRequest(address recipientToken, uint256 recipientTokenAmount) external returns (uint256 id) {
        require(recipientTokenAmount > 0, "createRequest/recipientTokenAmountZero");

        id = requests.length;
        requests.push(Request(payable(msg.sender), recipientToken, recipientTokenAmount, false));
        emit RequestCreated(id, msg.sender, recipientToken, recipientTokenAmount);
    }

    function payRequest(
        PayRequestInputParams calldata params
    )
        external
        payable
        returns (uint256 excessNativeTokenBalance, uint256 excessErc20InputTokenBalance, uint256 excessErc20OutputTokenBalance)
    {
        Request storage request = requests[params.requestId];

        require(params.inputTokenAmount > 0, "payRequest/inputTokenAmountZero");
        require(!request.paid, "already paid");
        request.paid = true;

        bool inputIsNative = (params.inputToken == address(0));
        bool outputIsNative = (request.recipientToken == address(0));

        if (inputIsNative) {
            require(address(this).balance >= params.inputTokenAmount, "payRequest/nativeTokenAmountLessThanInputTokenAmount");

            if(!outputIsNative) {
                // Wrap native token
                IWrappedNativeToken(wrappedNativeToken).deposit{value: params.inputTokenAmount}();
            }
        } else {
            // Transfer tokens in
            require(
                IERC20(params.inputToken).transferFrom(msg.sender, address(this), params.inputTokenAmount),
                "payRequest/inputTokenTransferFailed"
            );
        }

        address erc20InputToken = inputIsNative ? wrappedNativeToken : params.inputToken;
        address erc20OutputToken = outputIsNative ? wrappedNativeToken : request.recipientToken;

        // Stright transfer if not overridden by swap below
        uint256 inputTokenAmountPaid = request.recipientTokenAmount; 
        if(erc20InputToken != erc20OutputToken)
        {
            (inputTokenAmountPaid,) = performSwap(erc20InputToken, erc20OutputToken, params.inputTokenAmount, request.recipientTokenAmount, params.swapContractAddress, params.swapContractCallData);
        }

        if(outputIsNative) {
            if(!inputIsNative) {
                // Unwrap
                IWrappedNativeToken(wrappedNativeToken).withdraw(IWrappedNativeToken(wrappedNativeToken).balanceOf(address(this)));
            }

            // Direct send
            payNativeRequestDirect(params.requestId);
        } else {
            // Direct transfer
            payErc20RequestDirect(params.requestId);
        }

        uint256 nativeTokenBalance = address(this).balance;
        uint256 erc20InputTokenBalance = IERC20(erc20InputToken).balanceOf(address(this));
        uint256 erc20OutputTokenBalance = IERC20(erc20OutputToken).balanceOf(address(this));

        emit RequestPaid(params.requestId, msg.sender, params.inputToken, inputTokenAmountPaid);
        return (nativeTokenBalance, erc20InputTokenBalance, erc20OutputTokenBalance);
    }

    function withdraw() public onlyOwner {
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "withdraw failed");
    }

    function withdrawToken(IERC20 token) public onlyOwner {
        require(token.transfer(msg.sender, token.balanceOf(address(this))), "transfer failed");
    }

    function getRequest(uint256 requestId)
        external
        view
        returns (address recipient, address recipientToken, uint256 recipientTokenAmount, bool paid)
    {
        Request storage request = requests[requestId];
        return (request.recipient, request.recipientToken, request.recipientTokenAmount, request.paid);
    }

    fallback() external payable {}

    receive() external payable {}
}
