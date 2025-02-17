// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICcip} from "../common/interfaces/ICcip.sol";
import {LibErrors} from "../common/libraries/LibErrors.sol";
import {ZERO_ADDRESS} from "../common/Constants.sol";
import {LancaPoolCommonStorage} from "./storages/LancaPoolCommonStorage.sol";
import {ILancaPool} from "./interfaces/ILancaPool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract LancaPoolCommon is LancaPoolCommonStorage, ILancaPool {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /* CONSTANT VARIABLES */
    uint256 internal constant PRECISION_HANDLER = 1e10;
    uint256 internal constant LP_FEE_FACTOR = 1000;
    uint256 internal constant LP_FEE_BPS = 10;
    uint256 internal constant BPS_DIVISOR = 10_000;

    /* IMMUTABLE VARIABLES */
    IERC20 internal immutable i_usdc;
    address internal immutable i_lancaBridge;
    address internal immutable i_messenger0;
    address internal immutable i_messenger1;
    address internal immutable i_messenger2;

    modifier onlyAllowListedSenderOfChainSelector(uint64 chainSelector, address sender) {
        require(
            s_dstPoolByChainSelector[chainSelector] == sender,
            LibErrors.Unauthorized(LibErrors.UnauthorizedType.notAllowedSender)
        );

        _;
    }

    constructor(address usdc, address lancaBridge, address[3] memory messengers) {
        i_usdc = IERC20(usdc);
        i_lancaBridge = lancaBridge;
        i_messenger0 = messengers[0];
        i_messenger1 = messengers[1];
        i_messenger2 = messengers[2];
    }

    /* MODIFIERS */
    /**
     * @notice modifier to check if the caller is the an approved messenger
     */
    modifier onlyMessenger() {
        require(
            _isMessenger(msg.sender),
            LibErrors.Unauthorized(LibErrors.UnauthorizedType.notMessenger)
        );
        _;
    }

    modifier onlyLancaBridge() {
        require(
            msg.sender == i_lancaBridge,
            LibErrors.Unauthorized(LibErrors.UnauthorizedType.notLancaBridge)
        );
        _;
    }

    /* EXTERNAL FUNCTIONS */
    function takeLoan(
        address token,
        uint256 amount,
        address receiver
    ) external onlyLancaBridge returns (uint256) {
        require(
            receiver != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        require(
            token == address(i_usdc),
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.notUsdcToken)
        );

        uint256 loanAmountAfterFee = amount - getDstTotalFeeInUsdc(amount);
        s_loansInUse += loanAmountAfterFee;
        IERC20(token).safeTransfer(receiver, loanAmountAfterFee);
        return loanAmountAfterFee;
    }

    function completeRebalancing(bytes32 id, uint256 amount) external onlyLancaBridge {
        // @dev TODO: mb move to transferFrom lanca bridge?

        // amount -= getDstTotalFeeInUsdc(amount);
        // s_loansInUse -= amount;

        uint256 loansInUse = s_loansInUse;
        (, s_loansInUse) = loansInUse.trySub(amount - getDstTotalFeeInUsdc(amount));
    }

    /* PUBLIC FUNCTIONS */

    function getDstTotalFeeInUsdc(uint256 amount) public pure returns (uint256) {
        return amount.mulDiv(LP_FEE_BPS, BPS_DIVISOR, Math.Rounding.Ceil);
    }

    /* INTERNAL FUNCTIONS */
    /**
     * @notice Internal function to check if a caller address is an allowed messenger
     * @param messenger the address of the caller
     * @return allowed true if the caller is an allowed messenger, false otherwise
     */
    function _isMessenger(address messenger) internal view returns (bool) {
        return messenger == i_messenger0 || messenger == i_messenger1 || messenger == i_messenger2;
    }
}
