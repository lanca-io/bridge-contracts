// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LPToken} from "./LPToken.sol";
import {LancaPoolCommon} from "./LancaPoolCommon.sol";

/**
 * @title LancaParentPoolCommon
 * @notice This contract is the base for all the parent pool contracts.
 */
abstract contract LancaParentPoolCommon is LancaPoolCommon {
    uint256 internal constant USDC_DECIMALS = 1e6;
    uint256 internal constant LP_TOKEN_DECIMALS = 1 ether;
    uint8 internal constant MAX_DEPOSITS_ON_THE_WAY_COUNT = 150;
    uint256 internal constant WITHDRAWAL_COOLDOWN_SECONDS = 597_600;

    LPToken public immutable i_lpToken;

    /**
     * @notice The parent pool proxy contract address.
     */
    address internal immutable i_parentPoolProxy;

    /**
     * @notice Constructor for the LancaParentPoolCommon contract.
     * @param parentPool the parent pool proxy contract address.
     * @param lpToken the LP token contract address.
     * @param usdc the USDC token contract address.
     * @param lancaBridge the LancaBridge contract address.
     * @param messengers the approved messengers.
     */
    constructor(
        address lpToken,
        address usdc,
        address lancaBridge,

    ) LancaPoolCommon(usdc, lancaBridge) {
        i_lpToken = LPToken(lpToken);
    }

    /* INTERNAL FUNCTIONS */

    function _convertToLPTokenDecimals(uint256 usdcAmount) internal pure returns (uint256) {
        return (usdcAmount * LP_TOKEN_DECIMALS) / USDC_DECIMALS;
    }

    function _convertToUSDCTokenDecimals(uint256 lpAmount) internal pure returns (uint256) {
        return (lpAmount * USDC_DECIMALS) / LP_TOKEN_DECIMALS;
    }
}
