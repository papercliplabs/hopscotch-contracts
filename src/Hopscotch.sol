// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IHopscotch} from "./IHopscotch.sol";

contract Hopscotch is IHopscotch {
    struct Request {
        address payable recipient;
        IERC20 recipientToken;
        uint256 recipientTokenAmount;
        bool paid;
    }

    Request[] public requests;

    // 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 10
    function createRequest(IERC20 recipientToken, uint256 recipientTokenAmount)
        external
        returns (uint256 id)
    {
        id = requests.length;

        // TODO: assert this is an erc20 token?
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
        IERC20 inputToken,
        uint256 inputTokenAmount,
        address swapContractAddress,
        bytes calldata swapContractCallData
    ) external payable {
        Request storage request = requests[requestId];

        require(!request.paid, "already paid");
        request.paid = true;

        // Transfer input tokens from caller to this contrat, must be approved for this
        // TODO - wrap if needed
        require(
            inputToken.transferFrom(
                msg.sender,
                address(this),
                inputTokenAmount
            ),
            "payRequest/inputTokenTransfer"
        );

        // Grab balances before swap to compare with after
        uint256 inputTokenBalanceBeforeSwap = inputToken.balanceOf(
            address(this)
        );
        uint256 outputTokenBalanceBeforeSwap = request.recipientToken.balanceOf(
            address(this)
        );

        // Allow swap contract to spend this amount of tokens
        inputToken.approve(swapContractAddress, inputTokenAmount);

        // Execute swap
        (bool swapSuccess, ) = swapContractAddress.call(swapContractCallData);
        require(swapSuccess, "payRequest/swap");

        // Check output balance increaced by at least request amount
        uint256 inputTokenAmountPaid = inputTokenBalanceBeforeSwap -
            inputToken.balanceOf(address(this));
        uint256 outputTokenAmountReceived = request.recipientToken.balanceOf(
            address(this)
        ) - outputTokenBalanceBeforeSwap;
        require(
            outputTokenAmountReceived >= request.recipientTokenAmount,
            "payRequest/notEnoughOutputTokensFromSwap"
        );

        // Revoke input token approval
        inputToken.approve(swapContractAddress, 0);

        // Pay the request - TODO: unwrap and transfer ETH if needed
        request.recipientToken.transfer(
            request.recipient,
            request.recipientTokenAmount
        );

        // Refund remaining input tokens
        if (inputTokenAmountPaid < inputTokenAmount) {
            inputToken.transfer(
                msg.sender,
                inputTokenAmount - inputTokenAmountPaid
            );
        }

        // Refund remaining output tokens
        if (outputTokenAmountReceived > request.recipientTokenAmount) {
            request.recipientToken.transfer(
                msg.sender,
                outputTokenAmountReceived - request.recipientTokenAmount
            );
        }

        emit RequestPaid(
            requestId,
            msg.sender,
            inputToken,
            inputTokenAmountPaid
        );
    }

    function payRequest(uint256 requestId) external payable {
        Request storage request = requests[requestId];

        require(!request.paid, "already paid");
        request.paid = true;

        require(
            request.recipientToken.transferFrom(
                msg.sender,
                address(this),
                request.recipientTokenAmount
            ),
            "payRequest/directInputTokenTransfer"
        );
    }

    function withdraw() public {
        // TODO: onlyOwner
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "withdraw failed");
    }

    function withdrawToken(IERC20 token) public {
        // TODO: onlyOwner
        token.transfer(msg.sender, token.balanceOf(address(this)));
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
            address(request.recipientToken),
            request.recipientTokenAmount,
            request.paid
        );
    }

    fallback() external payable {}

    receive() external payable {}
}
