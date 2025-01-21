// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICcip} from "../interfaces/ICcip.sol";

abstract contract LancaPoolCommon {
    using SafeERC20 for IERC20;
    /**
     * @notice Thrown when the caller is not an approved messenger.
     */
    error NotMessenger();

    /* CONSTANT VARIABLES */
    uint256 internal constant PRECISION_HANDLER = 1e10;

    /* IMMUTABLE VARIABLES */
    IERC20 internal immutable i_USDC;
    address internal immutable i_msgr0;
    address internal immutable i_msgr1;
    address internal immutable i_msgr2;

    constructor(address usdc, address[3] memory messengers) {
        i_USDC = IERC20(usdc);
        (i_msgr0, i_msgr1, i_msgr2) = messengers;
    }

    /* MODIFIERS */
    /**
     * @notice modifier to check if the caller is the an approved messenger
     */
    modifier onlyMessenger() {
        if (!_isMessenger(msg.sender)) revert NotMessenger();
        _;
    }

    /* INTERNAL FUNCTIONS */
    /**
     * @notice Internal function to check if a caller address is an allowed messenger
     * @param messenger the address of the caller
     * @return allowed true if the caller is an allowed messenger, false otherwise
     */
    function _isMessenger(address messenger) internal view returns (bool) {
        return (messenger == i_msgr0 || messenger == i_msgr1 || messenger == i_msgr2);
    }
}
