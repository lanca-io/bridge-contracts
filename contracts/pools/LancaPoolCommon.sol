// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICcip} from "../interfaces/ICcip.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {LancaPoolStorage} from "../storages/LancaPoolStorage.sol";
import {ZERO_ADDRESS} from "../Constants.sol";

abstract contract LancaPoolCommon is LancaPoolStorage {
    using SafeERC20 for IERC20;

    /* CONSTANT VARIABLES */
    uint256 internal constant PRECISION_HANDLER = 1e10;

    /* IMMUTABLE VARIABLES */
    IERC20 internal immutable i_usdc;
    address internal immutable i_lancaBridge;
    address internal immutable i_msgr0;
    address internal immutable i_msgr1;
    address internal immutable i_msgr2;

    constructor(address usdc, address lancaBridge, address[3] memory messengers) {
        i_usdc = IERC20(usdc);
        i_lancaBridge = lancaBridge;
        i_msgr0 = messengers[0];
        i_msgr1 = messengers[1];
        i_msgr2 = messengers[2];
    }

    /* MODIFIERS */
    /**
     * @notice modifier to check if the caller is the an approved messenger
     */
    modifier onlyMessenger() {
        require(
            _isMessenger(msg.sender),
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.notMessenger)
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
    function takeLoan(address token, uint256 amount, address receiver) external payable {
        require(
            receiver != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        require(
            token == address(i_usdc),
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.notUsdcToken)
        );
        IERC20(token).safeTransfer(receiver, amount);
        s_loansInUse += amount;
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
