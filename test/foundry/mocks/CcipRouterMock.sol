// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CcipRouterMock {
    error UnsupportedCcipFeeToken();

    uint256 private constant CCIP_FEE_IN_LINK = 0.03234e18;

    address private immutable i_link;

    // @dev needed for generation of unique ids
    uint256 private s_nonce;

    constructor(address link) {
        i_link = link;
    }

    function ccipSend(
        uint64,
        Client.EVM2AnyMessage memory evm2AnyMessage
    ) external payable returns (bytes32) {
        if (evm2AnyMessage.feeToken != i_link) revert UnsupportedCcipFeeToken();

        IERC20(i_link).transferFrom(msg.sender, address(this), _getFee(evm2AnyMessage));

        for (uint256 i; i < evm2AnyMessage.tokenAmounts.length; ++i) {
            IERC20(evm2AnyMessage.tokenAmounts[i].token).transferFrom(
                msg.sender,
                address(this),
                evm2AnyMessage.tokenAmounts[i].amount
            );
        }

        return keccak256(abi.encode(block.number, ++s_nonce));
    }

    function getFee(
        uint64,
        Client.EVM2AnyMessage memory evm2AnyMessage
    ) external view returns (uint256) {
        return _getFee(evm2AnyMessage);
    }

    function _getFee(Client.EVM2AnyMessage memory evm2AnyMessage) internal view returns (uint256) {
        if (evm2AnyMessage.feeToken != i_link) revert UnsupportedCcipFeeToken();

        return CCIP_FEE_IN_LINK;
    }
}
