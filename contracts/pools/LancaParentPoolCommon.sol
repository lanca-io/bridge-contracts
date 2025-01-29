// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LPToken} from "../LPToken.sol";
import {LancaPoolCommon} from "./LancaPoolCommon.sol";
import {ICcip} from "../interfaces/ICcip.sol";

/**
 * @title LancaParentPoolCommon
 * @notice This contract is the base for all the parent pool contracts.
 */
contract LancaParentPoolCommon is LancaPoolCommon {
    /**
     * @notice The USDC token decimals.
     */
    uint256 internal constant USDC_DECIMALS = 1e6;

    /**
     * @notice The LP token decimals.
     */
    uint256 internal constant LP_TOKEN_DECIMALS = 1 ether;

    /**
     * @notice The maximum number of deposits on the way.
     */
    uint8 internal constant MAX_DEPOSITS_ON_THE_WAY_COUNT = 150;

    /**
     * @notice The withdrawal cooldown in seconds.
     */
    uint256 internal constant WITHDRAWAL_COOLDOWN_SECONDS = 597_600;

    /**
     * @notice The LP token contract.
     */
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
     * @param messengers the approved messengers.
     */
    constructor(
        address parentPool,
        address lpToken,
        address usdc,
        address[3] memory messengers
    ) LancaPoolCommon(usdc, messengers) {
        i_parentPoolProxy = parentPool;
        i_lpToken = LPToken(lpToken);
    }

    /* INTERNAL FUNCTIONS */
    /**
     * @notice Internal function to convert USDC Decimals to LP Decimals
     * @param usdcAmount the amount of USDC
     * @return adjustedAmount the adjusted amount
     */
    function _convertToLPTokenDecimals(uint256 usdcAmount) internal pure returns (uint256) {
        return (usdcAmount * LP_TOKEN_DECIMALS) / USDC_DECIMALS;
    }

    /**
     * @notice Internal function to convert LP Decimals to USDC Decimals
     * @param lpAmount the amount of LP
     * @return adjustedAmount the adjusted amount
     */
    function _convertToUSDCTokenDecimals(uint256 lpAmount) internal pure returns (uint256) {
        return (lpAmount * USDC_DECIMALS) / LP_TOKEN_DECIMALS;
    }

    /**
     * @notice Function to distribute funds automatically right after LP deposits into the pool
     * @dev this function will only be called internally.
     */
    function _ccipSend(
        uint64 chainSelector,
        uint256 amount,
        ICcip.CcipTxType ccipTxType
    ) internal returns (bytes32);
}
