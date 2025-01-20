// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LPToken} from "../LPToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title LancaParentPoolCommon
 * @notice This contract is the base for all the parent pool contracts.
 */
contract LancaParentPoolCommon {
    /**
     * @notice Thrown when the function is not being executed in the proxy context.
     * @param sender the address of the sender
     */
    error NotParentPoolProxy(address sender);

    /**
     * @notice Thrown when the caller is not an approved messenger.
     */
    error NotMessenger();

    /**
     * @notice The USDC token decimals.
     */
    uint256 internal constant USDC_DECIMALS = 1e6;

    /**
     * @notice The LP token decimals.
     */
    uint256 internal constant LP_TOKEN_DECIMALS = 1 ether;

    /**
     * @notice The precision handler for calculations.
     */
    uint256 internal constant PRECISION_HANDLER = 1e10;

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
     * @notice The USDC token contract.
     */
    IERC20 internal immutable i_USDC;

    /**
     * @notice The approved messengers.
     */
    address internal immutable i_msgr0;
    address internal immutable i_msgr1;
    address internal immutable i_msgr2;

    /**
     * @notice Modifier to ensure if the function is being executed in the proxy context.
     */
    modifier onlyProxyContext() {
        if (address(this) != i_parentPoolProxy) {
            revert NotParentPoolProxy(address(this));
        }
        _;
    }

    /**
     * @notice Modifier to check if the caller is the an approved messenger.
     */
    modifier onlyMessenger() {
        require(_isMessenger(msg.sender), NotMessenger());
        _;
    }

    /**
     * @notice Constructor for the LancaParentPoolCommon contract.
     * @param parentPool the parent pool proxy contract address.
     * @param lpToken the LP token contract address.
     * @param USDC the USDC token contract address.
     * @param messengers the approved messengers.
     */
    constructor(address parentPool, address lpToken, address USDC, address[3] memory messengers) {
        i_parentPoolProxy = parentPool;
        i_lpToken = LPToken(lpToken);
        (i_msgr0, i_msgr1, i_msgr2) = messengers;
        i_USDC = IERC20(USDC);
    }

    /**
     * @notice Internal function to check if a caller address is an allowed messenger
     * @param messenger the address of the caller
     * @return allowed true if the caller is an allowed messenger, false otherwise
     */
    function _isMessenger(address messenger) internal view returns (bool) {
        return (messenger == i_msgr0 || messenger == i_msgr1 || messenger == i_msgr2);
    }

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
}
