// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IHopscotch} from "./IHopscotch.sol";
import {IWrappedNativeToken} from "./IWrappedNativeToken.sol";

contract Hopscotch is IHopscotch, Ownable {
    struct Request {
        address payable recipient;
        address recipientToken;
        uint256 recipientTokenAmount;
        bool paid;
    }

    Request[] requests;
    IWrappedNativeToken public immutable wrappedNativeToken;

    /// @param _wrappedNativeToken wrapped native token address for the chain
    constructor(IWrappedNativeToken _wrappedNativeToken) {
        wrappedNativeToken = _wrappedNativeToken;
    }

    function createRequest(address recipientToken, uint256 recipientTokenAmount)
        external
        returns (uint256 id)
    {
        require(recipientTokenAmount > 0, "request amount must be >0");

        id = requests.length;

        requests.push(
            Request(
                payable(msg.sender),
                recipientToken,
                recipientTokenAmount,
                false
            )
        );

        emit RequestCreated(
            id,
            msg.sender,
            recipientToken,
            recipientTokenAmount
        );
    }

    function payRequest(
        uint256 requestId,
        address inputToken,
        uint256 inputTokenAmount,
        address swapContractAddress,
        bytes calldata swapContractCallData
    ) external payable {
        Request storage request = requests[requestId];

        require(inputTokenAmount > 0, "zero input token amount");
        require(!request.paid, "already paid");
        request.paid = true;

        bool inputIsNative = address(inputToken) == address(0);
        bool outputIsNative = address(request.recipientToken) == address(0);

        if (inputIsNative) {
            require(msg.value >= inputTokenAmount, "insufficient msg.value");
        }

        uint256 senderTokenAmount;
        if (inputIsNative && outputIsNative) {
            // Native token transfer
            (bool success, ) = request.recipient.call{
                value: request.recipientTokenAmount
            }("");
            require(success, "native token send failure");

            // Refund extra value
            if (msg.value > request.recipientTokenAmount) {
                (bool refundSuccess, ) = msg.sender.call{
                    value: msg.value - request.recipientTokenAmount
                }("");
                require(refundSuccess, "failed to refund native token");
            }

            senderTokenAmount = request.recipientTokenAmount;
        } else {
            IERC20 swapInputToken;
            if (inputIsNative) {
                swapInputToken = wrappedNativeToken;
            } else {
                swapInputToken = IERC20(inputToken);
            }

            IERC20 swapOutputToken;
            if (outputIsNative) {
                swapOutputToken = wrappedNativeToken;
            } else {
                swapOutputToken = IERC20(request.recipientToken);
            }

            // Transfer swap input token into this contract
            if (inputIsNative) {
                // Wrap any of the native token sent in if the input token is the wrapped native token
                wrappedNativeToken.deposit{value: msg.value}();
            } else {
                // Transfer input tokens from caller to this contrat, must be approved for this
                require(
                    swapInputToken.transferFrom(
                        msg.sender,
                        address(this),
                        inputTokenAmount
                    ),
                    "payRequest/inputTokenTransfer"
                );
            }

            // Perform swap if needed
            uint256 swapInputTokenRefund = 0;
            uint256 swapOutputTokenRefund = 0;
            if (swapInputToken != swapOutputToken) {
                // Grab balances before swap to compare with after
                uint256 swapInputTokenBalanceBeforeSwap = swapInputToken
                    .balanceOf(address(this));
                uint256 swapOutputTokenBalanceBeforeSwap = swapOutputToken
                    .balanceOf(address(this));

                // Allow swap contract to spend this amount of swap input tokens
                swapInputToken.approve(swapContractAddress, inputTokenAmount);

                // Execute swap
                (bool swapSuccess, ) = swapContractAddress.call(
                    swapContractCallData
                );
                require(swapSuccess, "payRequest/swap");

                // Check output balance increaced by at least request amount
                uint256 swapInputTokenAmountPaid = swapInputTokenBalanceBeforeSwap -
                        swapInputToken.balanceOf(address(this));
                uint256 swapOutputTokenAmountReceived = swapOutputToken
                    .balanceOf(address(this)) -
                    swapOutputTokenBalanceBeforeSwap;
                require(
                    swapOutputTokenAmountReceived >=
                        request.recipientTokenAmount,
                    "payRequest/notEnoughOutputTokensFromSwap"
                );

                // Revoke input token approval
                swapInputToken.approve(swapContractAddress, 0);

                if (inputTokenAmount - swapInputTokenAmountPaid > 0) {
                    swapInputTokenRefund =
                        inputTokenAmount -
                        swapInputTokenAmountPaid;
                }

                if (
                    swapOutputTokenAmountReceived > request.recipientTokenAmount
                ) {
                    swapOutputTokenRefund =
                        request.recipientTokenAmount -
                        swapOutputTokenAmountReceived;
                }
            } else {
                swapInputTokenRefund =
                    inputTokenAmount -
                    request.recipientTokenAmount;
            }

            // Pay the request
            if (outputIsNative) {
                // Unwrap and send
                wrappedNativeToken.withdraw(request.recipientTokenAmount);
                (bool success, ) = request.recipient.call{
                    value: request.recipientTokenAmount
                }("");
                require(success, "send of native tokens failed");
            } else {
                // Transfer
                require(
                    swapOutputToken.transfer(
                        request.recipient,
                        request.recipientTokenAmount
                    ),
                    "failed to pay request with erc20 token"
                );
            }

            // Refund remaining input tokens
            if (swapInputTokenRefund > 0) {
                if (inputIsNative) {
                    // unwrap and refund native
                    wrappedNativeToken.withdraw(swapInputTokenRefund);
                    (bool success, ) = request.recipient.call{
                        value: swapInputTokenRefund
                    }("");
                    require(success, "refund of native input tokens failed");
                } else {
                    require(
                        swapInputToken.transfer(
                            msg.sender,
                            swapInputTokenRefund
                        ),
                        "failed to refund excess input tokens"
                    );
                }
            }

            // Refund remaining output tokens
            if (swapOutputTokenRefund > 0) {
                if (outputIsNative) {
                    // unwrap and refund native
                    wrappedNativeToken.withdraw(swapOutputTokenRefund);
                    (bool success, ) = request.recipient.call{
                        value: swapOutputTokenRefund
                    }("");
                    require(success, "refund of native output tokens failed");
                } else {
                    require(
                        swapOutputToken.transfer(
                            msg.sender,
                            swapOutputTokenRefund
                        ),
                        "failed to refund excess output tokens"
                    );
                }
            }

            senderTokenAmount = inputTokenAmount - swapInputTokenRefund;
        }

        emit RequestPaid(requestId, msg.sender, inputToken, senderTokenAmount);
    }

    function withdraw() public onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "withdraw failed");
    }

    function withdrawToken(IERC20 token) public onlyOwner {
        require(
            token.transfer(msg.sender, token.balanceOf(address(this))),
            "transfer failed"
        );
    }

    function getRequest(uint256 requestId)
        external
        view
        returns (
            address recipient,
            address recipientToken,
            uint256 recipientTokenAmount,
            bool paid
        )
    {
        Request storage request = requests[requestId];
        return (
            request.recipient,
            request.recipientToken,
            request.recipientTokenAmount,
            request.paid
        );
    }

    fallback() external payable {}

    receive() external payable {}
}
